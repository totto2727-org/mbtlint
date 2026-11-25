///|
pub fn with_simplifications(config : @core.Config) -> @core.Config {
  config
  .with_rule(@rule.simplify_bool_if())
  .with_rule(@rule.simplify_bool_match())
  .with_rule(@rule.redundant_bool_pattern())
  .with_rule(@rule.constant_condition())
  .with_rule(@rule.redundant_bool_operand())
  .with_rule(@rule.no_self_assignment())
}
