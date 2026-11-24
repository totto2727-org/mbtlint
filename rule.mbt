///|
#derive(Eq)
pub(all) enum Severity {
  Warning
  Error
}

///|
pub struct Diagnostic {
  path : String
  rule_id : String?
  severity : Severity
  loc : @basic.Location
  message : String
}

///|
pub impl Show for Diagnostic with fn output(self, logger) {
  let level = match self.severity {
    Warning => "warning"
    Error => "error"
  }
  let id = self.rule_id.unwrap_or("parse")
  logger.write_string(
    "\{self.path}:\{self.loc.start.lnum}:\{self.loc.start.column()}: \{level} [\{id}] \{self.message}",
  )
}

///|
/// One context per rule per file. The engine supplies the path, rule ID and severity on report.
pub struct Context {
  path : String
  source : String
  program : @list.List[@syntax.Impl]
  report : (@basic.Location, String) -> Unit
}

///|
pub struct Listener {
  on_decl : ((@syntax.Impl) -> Unit)?
  on_expr : ((@syntax.Expr) -> Unit)?
}

///|
pub fn Listener::Listener(
  on_decl? : (@syntax.Impl) -> Unit,
  on_expr? : (@syntax.Expr) -> Unit,
) -> Listener {
  { on_decl, on_expr, }
}

///|
pub struct Rule {
  id : String
  create : (Context) -> Listener
}

///|
pub fn Rule::Rule(id : String, create : (Context) -> Listener) -> Rule {
  { id, create, }
}

///|
pub struct Config {
  priv rules : Array[(Rule, Severity)]
}

///|
/// Start without rules. Syntax errors are always reported.
pub fn Config::Config() -> Config {
  { rules: [], }
}

///|
/// Return a new configuration. The last registration of an ID wins.
pub fn Config::with_rule(
  self : Config,
  rule : Rule,
  severity~ : Severity = Error,
) -> Config {
  let rules = self.rules.filter(entry => entry.0.id != rule.id)
  rules.push((rule, severity))
  { rules, }
}

///|
pub fn Config::without_rule(self : Config, id : String) -> Config {
  { rules: self.rules.filter(entry => entry.0.id != id), }
}
