///|
using @syntax {trait IterVisitor}

///|
priv struct Walk(Array[Listener])

///|
impl IterVisitor for Walk with fn visit_Expr(self, expr) {
  for listener in self.0 {
    if listener.on_expr is Some(visit) {
      visit(expr)
    }
  }
  IterVisitor::visit_Expr(IterVisitor::base(self), expr)
}

///|
/// Parse once. Only run listeners on a syntactically valid file.
pub fn Config::lint(
  self : Config,
  path~ : String,
  source~ : String,
) -> Array[Diagnostic] {
  let (program, errors) = if path.has_suffix(".mbtx") {
    let (script, errors) = @parser.parse_mbtx_string(source, name=path)
    (script.body, errors)
  } else {
    @parser.parse_string(source, name=path)
  }
  if !errors.is_empty() {
    return errors.map(e => {
      path,
      rule_id: None,
      severity: Error,
      loc: e.loc,
      message: e.msg,
      fix: None,
    })
  }
  let diagnostics = []
  let offsets = LazyOffsets::{ source, table: None }
  let listeners = self.rules.map(entry => {
    let (rule, severity) = entry
    fn report(loc, message, fix) {
      diagnostics.push(Diagnostic::{ path, rule_id: Some(rule.id), severity, loc, message, fix })
    }
    (rule.create)({
      path,
      source,
      program,
      offsets,
      report: (loc, message) => report(loc, message, None),
      report_fix: (loc, message, replacement) => {
        let edit = offsets.range(path, loc).map(range => {
          let (start, end) = range
          Edit::{ start, end, replacement }
        })
        report(loc, message, edit)
      },
    })
  })
  let walk = Walk(listeners)
  for decl in program {
    for listener in listeners {
      if listener.on_decl is Some(visit) {
        visit(decl)
      }
    }
    IterVisitor::visit_Impl(walk, decl)
  }
  diagnostics
}
