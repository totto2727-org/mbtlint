///|
fn contract_prefix(name : String, word : String) -> Bool {
  name == word || name.has_prefix(word + "_")
}

///|
fn contract_safe_name(name : String) -> Bool {
  contract_prefix(name, "safe") ||
  contract_prefix(name, "try") ||
  name.has_suffix("_or_default") ||
  name.has_suffix("_or_none") ||
  name.has_suffix("_or_else")
}

///|
fn contract_pure_name(name : String) -> Bool {
  ["compute", "calculate", "derive", "format", "to", "parse"].any(word => {
    contract_prefix(name, word)
  })
}

///|
fn contract_literal_fallback(expr : @syntax.Expr) -> Bool {
  match expr {
    Group(expr~, ..) => contract_literal_fallback(expr)
    Return(return_value=Some(expr), ..) => contract_literal_fallback(expr)
    Return(return_value=None, ..) | Unit(..) => true
    Constant(c=String(_) | Int(_) | UInt(_) | Int64(_) | UInt64(_), ..) => true
    Array(exprs~, is_iter=false, ..) => exprs.is_empty()
    _ => false
  }
}

///|
priv struct ContractShadows(Array[String])

///|
impl IterVisitor for ContractShadows with fn visit_Binder(self, binder) {
  self.0.push(binder.name)
}

///|
fn contract_file_names(program : @list.List[@syntax.Impl]) -> Array[String] {
  let names = []
  for decl in program {
    match decl {
      TopFuncDef(fun_decl={ type_name: None, name, .. }, ..)
      | TopLetDef(binder=name, ..) => names.push(name.name)
      TopUsing(names=aliases, ..) =>
        for (target, kind) in aliases {
          if kind is Value {
            names.push(target.binder.name)
          }
        }
      _ => ()
    }
  }
  names
}

///|
fn contract_parameter_names(params : @syntax.Parameters?) -> Array[String] {
  let names = []
  if params is Some(params) {
    for param in params {
      match param {
        Positional(binder~, ..)
        | Labelled(binder~, ..)
        | Optional(binder~, ..)
        | QuestionOptional(binder~, ..) => names.push(binder.name)
        DiscardPositional(..) => ()
      }
    }
  }
  names
}

///|
fn contract_callee(expr : @syntax.Expr) -> @syntax.Var? {
  match expr {
    Apply(func=Ident(id~, ..), args~, ..) => {
      for arg in args {
        if arg.value is Hole(kind=Incomplete, ..) {
          return None
        }
      }
      Some(id)
    }
    Pipe(rhs=Ident(id~, ..), ..) | RevPipe(lhs=Ident(id~, ..), ..) => Some(id)
    _ => None
  }
}

///|
fn contract_core_call(
  expr : @syntax.Expr,
  shadows : Array[String],
) -> (String, @basic.Location)? {
  guard contract_callee(expr) is Some({ name, loc, }) else { return None }
  match name {
    Ident(name~) if !shadows.contains(name) => Some((name, loc))
    Dot(pkg="builtin" | "prelude", id~) => Some((id, loc))
    _ => None
  }
}

///|
fn contract_receiver_root(expr : @syntax.Expr) -> String? {
  match expr {
    Ident(id={ name: Ident(name~), .. }, ..) => Some(name)
    Field(record~, ..) => contract_receiver_root(record)
    Group(expr~, ..) => contract_receiver_root(expr)
    _ => None
  }
}

///|
priv struct ContractBody((@syntax.Expr) -> Unit)

///|
impl IterVisitor for ContractBody with fn visit_Expr(self, expr) {
  (self.0)(expr)
  match expr {
    // A closure or a local function declaration is not an execution of its body.
    Function(..) => ()
    LetFn(body~, ..) | LetAnd(body~, ..) => IterVisitor::visit_Expr(self, body)
    _ => IterVisitor::visit_Expr(IterVisitor::base(self), expr)
  }
}

///|
/// Report wildcard catches with a literal fallback in explicitly plain-returning functions.
pub fn catch_hides_failure() -> Rule {
  builtin_rule("catch-hides-failure", ctx => {
    Listener(on_decl=decl => {
      guard decl
        is TopFuncDef(
          fun_decl={ name, return_type, .. },
          decl_body=DeclBody(expr~),
          ..
        ) else {
        return
      }
      let name = name.name
      guard !["safe", "try", "maybe"].any(word => contract_prefix(name, word)) &&
        !["_or_null", "_or_default", "_or_else", "_or_none", "_or"].any(suffix => {
          name.has_suffix(suffix)
        }) else {
        return
      }
      guard return_type
        is Some(
          Name(
            constr_id={
              id: Ident(
                name="String"
                | "Int"
                | "Int64"
                | "UInt"
                | "UInt64"
                | "Unit"
                | "Array",
              ),
              ..
            },
            ..
          ),
        ) else {
        return
      }
      IterVisitor::visit_Expr(
        ContractBody(node => {
          if node is Try(catch_~, ..) {
            for case in catch_ {
              if case is { pattern: Any(loc~), guard_: None, body, } &&
                contract_literal_fallback(body) {
                (ctx.report)(
                  loc, "This wildcard catch discards the error and substitutes a literal fallback.",
                )
              }
            }
          }
        }),
        expr,
      )
    })
  })
}

///|
/// Report direct core abort or panic calls in conventionally safe-named functions.
pub fn safe_name_is_safe() -> Rule {
  builtin_rule("safe-name-is-safe", ctx => {
    let file_names = contract_file_names(ctx.program)
    Listener(on_decl=decl => {
      guard decl
        is TopFuncDef(
          fun_decl={ name, decl_params, .. },
          decl_body=DeclBody(expr~),
          ..
        ) &&
        contract_safe_name(name.name) else {
        return
      }
      let local_names = contract_parameter_names(decl_params)
      IterVisitor::visit_Expr(ContractShadows(local_names), expr)
      let shadows = file_names + local_names
      IterVisitor::visit_Expr(
        ContractBody(node => {
          if contract_core_call(node, shadows) is Some(("abort" | "panic", loc)) {
            (ctx.report)(
              loc, "This safe-named function calls a core panic operation directly.",
            )
          }
        }),
        expr,
      )
    })
  })
}

///|
/// Report direct output and parameter field writes in conventionally pure-named functions.
pub fn pure_name_is_pure() -> Rule {
  builtin_rule("pure-name-is-pure", ctx => {
    let file_names = contract_file_names(ctx.program)
    Listener(on_decl=decl => {
      guard decl
        is TopFuncDef(
          fun_decl={ name, decl_params, .. },
          decl_body=DeclBody(expr~),
          ..
        ) &&
        contract_pure_name(name.name) else {
        return
      }
      let params = contract_parameter_names(decl_params)
      let local_names = []
      IterVisitor::visit_Expr(ContractShadows(local_names), expr)
      let shadows = file_names + params + local_names
      IterVisitor::visit_Expr(
        ContractBody(node => {
          if contract_core_call(node, shadows) is Some(("println", loc)) {
            (ctx.report)(
              loc, "This computation-named function prints directly to stdout.",
            )
          }
          if node is Mutate(record~, loc~, ..) &&
            contract_receiver_root(record) is Some(root) &&
            params.contains(root) &&
            !local_names.contains(root) {
            (ctx.report)(
              loc, "This computation-named function writes to a field of a parameter.",
            )
          }
        }),
        expr,
      )
    })
  })
}

///|
/// Enable the opt-in static name and error handling checks at error severity.
pub fn Config::with_static_contracts(self : Config) -> Config {
  self
  .with_rule(catch_hides_failure())
  .with_rule(safe_name_is_safe())
  .with_rule(pure_name_is_pure())
}
