///|
fn safety_listener(
  ctx : Context,
  check : (@syntax.Expr) -> (@basic.Location, String)?,
) -> Listener {
  let mut expects_panic = false
  Listener(
    on_decl=decl => {
      expects_panic = match decl {
        TopTest(name=Some((name, _)), ..) =>
          name == "panic" ||
          name.has_prefix("panic ") ||
          name.has_prefix("panic_")
        _ => false
      }
    },
    on_expr=expr => {
      if !expects_panic && check(expr) is Some((loc, message)) {
        (ctx.report)(loc, message)
      }
    },
  )
}

///|
fn safety_ungroup(expr : @syntax.Expr) -> @syntax.Expr {
  match expr {
    Group(expr~, ..) => safety_ungroup(expr)
    _ => expr
  }
}

///|
fn safety_callee(expr : @syntax.Expr) -> @syntax.Expr? {
  match expr {
    Apply(func~, ..) => Some(safety_ungroup(func))
    Pipe(rhs=callee, ..) | RevPipe(lhs=callee, ..) =>
      match safety_ungroup(callee) {
        // Applied pipe targets are already visited as calls.
        Ident(_) | Method(_) as callee => Some(callee)
        _ => None
      }
    _ => None
  }
}

///|
fn safety_declares_value(
  program : @list.List[@syntax.Impl],
  name : String,
) -> Bool {
  for decl in program {
    match decl {
      TopFuncDef(fun_decl={ type_name: None, name: binder, .. }, ..)
      | TopLetDef(binder~, ..) => if binder.name == name { return true }
      _ => ()
    }
  }
  false
}

///|
/// Report explicit calls to the core abort and panic functions.
pub fn no_panic() -> Rule {
  builtin_rule("no-panic", ctx => {
    let shadows_abort = safety_declares_value(ctx.program, "abort")
    let shadows_panic = safety_declares_value(ctx.program, "panic")
    safety_listener(ctx, expr => {
      guard safety_callee(expr) is Some(Ident(id={ name, loc, }, ..)) else {
        None
      }
      let unsafe_call = match name {
        Ident(name="abort") => !shadows_abort
        Ident(name="panic") => !shadows_panic
        Dot(pkg="builtin" | "prelude", id="abort" | "panic")
        | Dot(pkg="abort", id="abort") => true
        _ => false
      }
      if unsafe_call {
        Some((loc, "Return or raise a recoverable error instead of panicking."))
      } else {
        None
      }
    })
  })
}

///|
fn safety_core_owner(name : @syntax.LongIdent) -> String? {
  match name {
    Ident(name~) | Dot(pkg="builtin" | "prelude", id=name) => Some(name)
    Dot(pkg="list", id="List") => Some("List")
    Dot(pkg="string", id="Regex") => Some("Regex")
    Dot(pkg="array", id="View") => Some("ArrayView")
    Dot(pkg="bytes", id="View") => Some("BytesView")
    Dot(pkg="string", id="View") => Some("StringView")
    _ => None
  }
}

///|
/// Report unchecked unwrapping of Option and Result values.
pub fn no_unsafe_unwrap() -> Rule {
  builtin_rule("no-unsafe-unwrap", ctx => {
    safety_listener(ctx, expr => {
      let candidate = match expr {
        DotApply(method_name=label, args~, ..) if args.is_empty() => Some(label)
        _ =>
          match safety_callee(expr) {
            Some(Method(type_name={ name, .. }, method_name=label, ..)) => {
              let owner = safety_core_owner(name)
              if owner is Some("Result") ||
                (owner is Some("Option") && label.name == "unwrap") {
                Some(label)
              } else {
                None
              }
            }
            _ => None
          }
      }
      if candidate is Some({ name: "unwrap" | "unwrap_err", loc, }) {
        Some((loc, "Handle both cases instead of using an unchecked unwrap."))
      } else {
        None
      }
    })
  })
}

///|
/// Report `try!`, which turns a raised error into a panic.
pub fn no_try_bang() -> Rule {
  builtin_rule("no-try-bang", ctx => {
    safety_listener(ctx, expr => {
      if expr is TryOperator(kind=Exclamation, try_loc~, ..) {
        Some((try_loc, "Handle or propagate the error instead of using try!."))
      } else {
        None
      }
    })
  })
}

///|
fn safety_is_unchecked_method(name : String, owner : String?) -> Bool {
  match name {
    "unsafe_get" =>
      owner is (None | Some("Array" | "MutArrayView" | "StringView"))
    "unsafe_set" | "unsafe_mut_view" =>
      owner is (None | Some("Array" | "MutArrayView")) ||
      (name == "unsafe_mut_view" && owner is Some("FixedArray"))
    "unsafe_view" =>
      owner
      is (None
      | Some(
        "Array"
        | "ArrayView"
        | "Bytes"
        | "BytesView"
        | "FixedArray"
        | "MutArrayView"
        | "ReadOnlyArray"
        | "String"
        | "StringView"
        | "UninitializedArray",
      ))
    "unsafe_range_equal" => owner is (None | Some("Bytes" | "String"))
    "unsafe_char_at" | "unsafe_substring" => owner is (None | Some("String"))
    "unsafe_charcode_at" => owner is (None | Some("StringView"))
    "unsafe_blit_fixed" => owner is (None | Some("Array"))
    "unsafe_blit"
    | "unsafe_write_uint16_be"
    | "unsafe_write_uint16_le"
    | "unsafe_write_uint32_be"
    | "unsafe_write_uint32_le"
    | "unsafe_write_uint64_be"
    | "unsafe_write_uint64_le" => owner is (None | Some("FixedArray"))
    "unsafe_tail" => owner is (None | Some("List"))
    "unsafe_from_string" => owner is (None | Some("Regex"))
    _ => false
  }
}

///|
/// Report calls to known unchecked core operations.
pub fn no_unsafe_operations() -> Rule {
  builtin_rule("no-unsafe-operations", ctx => {
    safety_listener(ctx, expr => {
      let candidate = match expr {
        DotApply(method_name=label, ..) if safety_is_unchecked_method(
            label.name,
            None,
          ) => Some(label)
        _ =>
          match safety_callee(expr) {
            Some(Method(type_name={ name, .. }, method_name=label, ..)) =>
              if safety_core_owner(name) is Some(owner) &&
                safety_is_unchecked_method(label.name, Some(owner)) {
                Some(label)
              } else {
                None
              }
            _ => None
          }
      }
      if candidate is Some({ name, loc, }) {
        Some((loc, "Use a checked operation instead of \{name}."))
      } else {
        None
      }
    })
  })
}

///|
/// Enable the safety rule pack at error severity.
pub fn Config::with_safety(self : Config) -> Config {
  self
  .with_rule(no_panic())
  .with_rule(no_unsafe_unwrap())
  .with_rule(no_try_bang())
  .with_rule(no_unsafe_operations())
}
