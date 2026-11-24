///|
fn simplification_ungroup(expr : @syntax.Expr) -> @syntax.Expr {
  for current = expr {
    match current {
      Group(expr~, ..) => continue expr
      other => break other
    }
  }
}

///|
fn simplification_bool(expr : @syntax.Expr) -> Bool? {
  match simplification_ungroup(expr) {
    Constant(c=Bool(value), ..) => Some(value)
    _ => None
  }
}

///|
fn simplification_bool_result(
  ctx : Context,
  loc : @basic.Location,
  operand : @syntax.Expr,
  negate : Bool,
  message : String,
  allow_fix~ : Bool = true,
) -> Unit {
  let operand_loc = operand.loc()
  if allow_fix &&
    operand_loc.start.cnum >= loc.start.cnum &&
    operand_loc.end.cnum <= loc.end.cnum &&
    ctx.text(loc) is Some(original) &&
    !original.contains("//") &&
    !original.contains("/*") &&
    !original.contains("#|") &&
    !original.contains("$|") &&
    ctx.text(operand_loc) is Some(text) &&
    !text.is_empty() {
    // Preserve the original Bool expectation even in polymorphic contexts.
    let replacement = if negate { "(!(\{text}))" } else { "((\{text}) : Bool)" }
    (ctx.report_fix)(loc, message, replacement)
  } else {
    (ctx.report)(loc, message)
  }
}

///|
/// Use the condition or its negation instead of opposite Boolean branches.
pub fn simplify_bool_if() -> Rule {
  builtin_rule("simplify-bool-if", ctx => {
    let else_if_starts : Set[Int32] = Set([])
    Listener(on_expr=expr => {
      guard expr is If(cond~, ifso~, ifnot=Some(otherwise), loc~) else {
        return
      }
      if otherwise is If(loc=child, ..) {
        else_if_starts.add(child.start.cnum)
      }
      if simplification_bool(cond) is None &&
        simplification_bool(ifso) is Some(yes) &&
        simplification_bool(otherwise) is Some(no) &&
        yes != no {
        let message = if yes {
          "Use the Boolean condition directly."
        } else {
          "Use the negation of the Boolean condition."
        }
        // A bare expression cannot replace the `if` directly following `else`.
        simplification_bool_result(
          ctx,
          loc,
          cond,
          !yes,
          message,
          allow_fix=!else_if_starts.contains(loc.start.cnum),
        )
      }
    })
  })
}

///|
/// Use the Boolean scrutinee or its negation instead of a two-arm match.
pub fn simplify_bool_match() -> Rule {
  builtin_rule("simplify-bool-match", ctx => {
    Listener(on_expr=expr => {
      guard expr is Match(expr=value, cases~, loc~, ..) &&
        cases is More(first, tail=More(second, tail=Empty)) &&
        first.guard_ is None &&
        second.guard_ is None &&
        first.pattern is Constant(c=Bool(first_input), ..) &&
        second.pattern is Constant(c=Bool(second_input), ..) &&
        first_input != second_input &&
        simplification_bool(first.body) is Some(first_output) &&
        simplification_bool(second.body) is Some(second_output) &&
        first_output != second_output else {
        return
      }
      let negate = first_input != first_output
      let message = if negate {
        "Use the negation of the Boolean scrutinee."
      } else {
        "Use the Boolean scrutinee directly."
      }
      simplification_bool_result(ctx, loc, value, negate, message)
    })
  })
}

///|
/// Test a Boolean directly instead of matching a Boolean literal with `is`.
pub fn redundant_bool_pattern() -> Rule {
  builtin_rule("redundant-bool-pattern", ctx => {
    Listener(on_expr=expr => {
      if expr is Is(expr=value, pat=Constant(c=Bool(expected), ..), loc~) {
        let message = if expected {
          "Use the Boolean expression directly instead of `is true`."
        } else {
          "Negate the Boolean expression instead of matching `is false`."
        }
        simplification_bool_result(ctx, loc, value, !expected, message)
      }
    })
  })
}

///|
/// Report literal `if`, `guard`, and explicit C-style `for` conditions, and `while false`.
pub fn constant_condition() -> Rule {
  builtin_rule("constant-condition", ctx => {
    Listener(on_expr=expr => {
      match expr {
        If(cond~, ..) | Guard(cond~, ..) | For(condition=Some(cond), ..) =>
          if simplification_bool(cond) is Some(value) {
            (ctx.report)(cond.loc(), "This condition is always \{value}.")
          }
        While(loop_cond~, ..) =>
          if simplification_bool(loop_cond) is Some(false) {
            (ctx.report)(
              loop_cond.loc(),
              "This loop condition is always false.",
            )
          }
        _ => ()
      }
    })
  })
}

///|
/// Report redundant Boolean identity operands without changing short-circuit scopes.
pub fn redundant_bool_operand() -> Rule {
  builtin_rule("redundant-bool-operand", ctx => {
    Listener(on_expr=expr => {
      if expr is Infix(op={ name: Ident(name~), .. }, lhs~, rhs~, loc~) &&
        (name == "&&" || name == "||") {
        let identity = name == "&&"
        let left = simplification_bool(lhs)
        let right = simplification_bool(rhs)
        // Leave pairs of literals to a constant-expression analysis.
        if (left == Some(identity) && right is None) ||
          (left is None && right == Some(identity)) {
          (ctx.report)(
            loc, "This Boolean operation has a redundant literal operand.",
          )
        }
      }
    })
  })
}

///|
/// Report exact, unqualified variable self-assignment, not field or index writes.
pub fn no_self_assignment() -> Rule {
  builtin_rule("no-self-assignment", ctx => {
    Listener(on_expr=expr => {
      if expr
        is Assign(
          var_={ name: Ident(name=target), .. },
          expr=value,
          augmented_by=None,
          loc~,
        ) &&
        simplification_ungroup(value)
        is Ident(id={ name: Ident(name=source), .. }, ..) &&
        target == source {
        (ctx.report)(
          loc, "This assignment writes the variable's current value back to itself.",
        )
      }
    })
  })
}

///|
pub fn Config::with_simplifications(self : Config) -> Config {
  self
  .with_rule(simplify_bool_if())
  .with_rule(simplify_bool_match())
  .with_rule(redundant_bool_pattern())
  .with_rule(constant_condition())
  .with_rule(redundant_bool_operand())
  .with_rule(no_self_assignment())
}
