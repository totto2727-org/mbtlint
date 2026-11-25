///|
using @syntax {trait IterVisitor}

///|
priv struct Walk(Array[(@syntax.Expr) -> Unit])

///|
impl IterVisitor for Walk with fn visit_Expr(self, expr) {
  for visit in self.0 {
    visit(expr)
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
  if self.rules.is_empty() {
    return diagnostics
  }
  let offsets = LazyOffsets::{ source, table: None, }
  let decl_visitors = []
  let expr_visitors = []
  for entry in self.rules {
    let (rule, severity) = entry
    fn report(loc, message, fix) {
      diagnostics.push(Diagnostic::{
        path,
        rule_id: Some(rule.id),
        severity,
        loc,
        message,
        fix,
      })
    }
    let listener = (rule.create)({
      path,
      source,
      program,
      offsets,
      report: (loc, message) => report(loc, message, None),
      report_fix: (loc, message, replacement) => {
        let edit = offsets
          .range(path, loc)
          .map(range => {
            let (start, end) = range
            Edit::{ start, end, replacement, }
          })
        report(loc, message, edit)
      },
    })
    if listener.on_decl is Some(visit) {
      decl_visitors.push(visit)
    }
    if listener.on_expr is Some(visit) {
      expr_visitors.push(visit)
    }
  }
  let walk = Walk(expr_visitors)
  let visit_exprs = !expr_visitors.is_empty()
  for decl in program {
    for visit in decl_visitors {
      visit(decl)
    }
    if visit_exprs {
      IterVisitor::visit_Impl(walk, decl)
    }
  }
  diagnostics
}
