///|
/// Enable the safety rule pack at error severity.
pub fn with_safety(config : @core.Config) -> @core.Config {
  config
  .with_rule(@rule.no_panic())
  .with_rule(@rule.no_unsafe_unwrap())
  .with_rule(@rule.no_try_bang())
  .with_rule(@rule.no_unsafe_operations())
}
