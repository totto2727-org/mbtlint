///|
/// Enable the opt-in static name and error handling checks at error severity.
pub fn with_static_contracts(config : @core.Config) -> @core.Config {
  config
  .with_rule(@rule.catch_hides_failure())
  .with_rule(@rule.safe_name_is_safe())
  .with_rule(@rule.pure_name_is_pure())
}
