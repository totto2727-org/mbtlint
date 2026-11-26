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
pub fn no_manual_path_join() -> @core.Rule {
  builtin_rule("no-manual-path-join", ctx => {
    @core.Listener(on_expr=expr => {
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
