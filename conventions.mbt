///|
/// Require a nonempty documentation comment on exported declarations.
pub fn require_public_docs() -> Rule {
  builtin_rule("require-public-docs", ctx => {
    Listener(on_decl=decl => {
      let (vis, doc, loc) = match decl {
        TopFuncDef(fun_decl=f, ..) => (f.vis, f.doc, f.name.loc)
        TopTypeDef(t) => (t.type_vis, t.doc, t.tycon_loc)
        TopTrait(t) => (t.vis, t.doc, t.name.loc)
        TopLetDef(binder~, vis~, doc~, ..) => (vis, doc, binder.loc)
        _ => return
      }
      if vis is Pub(..) && doc.content.all(line => line.trim().is_empty()) {
        (ctx.report)(loc, "Document this public declaration with `///`.")
      }
    })
  })
}

///|
fn caller_parameters(decl : @syntax.FunDecl) -> @list.List[@syntax.Parameter] {
  guard decl.decl_params is Some(params) else { return @list.List([]) }
  match (decl.type_name, params) {
    (
      Some({ name: Ident(name=owner), .. }),
      More(
        Positional(
          ty=Some(Name(constr_id={ id: Ident(name=receiver), .. }, ..)),
          ..
        ),
        tail~,
      ),
    ) if receiver == owner && decl.name.name != owner => tail
    _ => params
  }
}

///|
/// Require labels when a function or method takes at least four caller-supplied parameters.
pub fn prefer_labelled_parameters() -> Rule {
  builtin_rule("prefer-labelled-parameters", ctx => {
    Listener(on_decl=decl => {
      guard decl is TopFuncDef(fun_decl~, decl_body=DeclBody(..), ..) else {
        return
      }
      let params = caller_parameters(fun_decl)
      if params.length() >= 4 &&
        params.any(param => param is (Positional(..) | DiscardPositional(..))) {
        (ctx.report)(
          fun_decl.name.loc,
          "Give every caller-supplied parameter a label when there are four or more.",
        )
      }
    })
  })
}

///|
fn without_parens(expr : @syntax.Expr) -> @syntax.Expr {
  match expr {
    Group(expr~, group=Paren, ..) => without_parens(expr)
    _ => expr
  }
}

///|
/// Prefer arrow syntax for inline callbacks without an explicit signature.
pub fn prefer_arrow_callback() -> Rule {
  builtin_rule("prefer-arrow-callback", ctx => {
    Listener(on_expr=expr => {
      let args = match expr {
        Apply(args~, ..) | DotApply(args~, ..) => args
        _ => return
      }
      for arg in args {
        if without_parens(arg.value)
          is Function(
            func={
              kind: Lambda,
              parameters,
              return_type: None,
              error_type: NoErrorType,
              is_async: None,
              nocancel_: None,
              ..
            },
            loc~,
          ) &&
          parameters.all(param => {
            param is (Positional(ty=None, ..) | DiscardPositional(ty=None, ..))
          }) {
          (ctx.report)(loc, "Use arrow syntax for this inline callback.")
        }
      }
    })
  })
}

///|
fn is_path_function(name : String) -> Bool {
  match name {
    "create_dir"
    | "is_dir"
    | "is_file"
    | "path_exists"
    | "read_dir"
    | "read_file_to_bytes"
    | "read_file_to_string"
    | "remove_dir"
    | "remove_file"
    | "write_bytes_to_file"
    | "write_string_to_file" => true
    _ => false
  }
}

///|
fn is_path_separator(expr : @syntax.Expr) -> Bool {
  // The parser retains string escapes, so a backslash literal has two backslashes here.
  without_parens(expr) is Constant(c=String("/" | "\\\\"), ..)
}

///|
fn has_joined_path_segments(expr : @syntax.Expr) -> Bool {
  guard without_parens(expr)
    is Infix(op={ name: Ident(name="+"), .. }, lhs~, rhs~, ..) else {
    return false
  }
  if without_parens(lhs)
    is Infix(op={ name: Ident(name="+"), .. }, rhs=separator, ..) &&
    is_path_separator(separator) {
    return true
  }
  if without_parens(rhs)
    is Infix(op={ name: Ident(name="+"), .. }, lhs=separator, ..) &&
    is_path_separator(separator) {
    return true
  }
  has_joined_path_segments(lhs) || has_joined_path_segments(rhs)
}

///|
/// Prefer a path join to explicit slash concatenation in known `@fs` path arguments.
pub fn no_manual_path_join() -> Rule {
  builtin_rule("no-manual-path-join", ctx => {
    Listener(on_expr=expr => {
      guard expr is Apply(func~, args~, ..) &&
        without_parens(func)
        is Ident(id={ name: Dot(pkg="fs", id=name), .. }, ..) &&
        is_path_function(name) &&
        args.head() is Some({ value, kind: Positional, }) &&
        has_joined_path_segments(value) else {
        return
      }
      (ctx.report)(
        value.loc(),
        "Join path segments with a path API before passing the path to `@fs`.",
      )
    })
  })
}

///|
/// Require a nonblank name on each test block.
pub fn require_named_tests() -> Rule {
  builtin_rule("require-named-tests", ctx => {
    Listener(on_decl=decl => {
      guard decl is TopTest(name~, loc~, ..) else { return }
      match name {
        None => (ctx.report)(loc, "Name this test to describe the scenario.")
        Some((title, title_loc)) if title.trim().is_empty() =>
          (ctx.report)(title_loc, "Give this test a nonblank name.")
        Some(_) => ()
      }
    })
  })
}

///|
fn without_expression_groups(expr : @syntax.Expr) -> @syntax.Expr {
  match expr {
    Group(expr~, ..) => without_expression_groups(expr)
    _ => expr
  }
}

///|
/// Prefer direct error propagation over catching and immediately raising the same error.
pub fn no_redundant_rethrow() -> Rule {
  builtin_rule("no-redundant-rethrow", ctx => {
    Listener(on_expr=expr => {
      guard expr is Try(catch_~, try_else=None, catch_loc~, ..) &&
        catch_
        is More({ pattern: Var({ name, .. }), guard_: None, body, }, tail=Empty) &&
        without_expression_groups(body) is Raise(err_value~, ..) &&
        without_parens(err_value)
        is Ident(id={ name: Ident(name=raised), .. }, ..) &&
        name == raised else {
        return
      }
      (ctx.report)(
        catch_loc, "Remove this catch and let the original error propagate.",
      )
    })
  })
}

///|
/// Enable the opt-in MoonBit conventions rules.
pub fn Config::with_conventions(self : Config) -> Config {
  self
  .with_rule(require_public_docs())
  .with_rule(prefer_labelled_parameters())
  .with_rule(prefer_arrow_callback())
  .with_rule(no_manual_path_join())
  .with_rule(require_named_tests())
  .with_rule(no_redundant_rethrow())
}
