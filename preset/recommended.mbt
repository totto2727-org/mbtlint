///|
pub fn recommended() -> @core.Config {
  let config = with_safety(@core.Config())
    .with_rule(@rule.no_mut())
    .with_rule(@rule.no_todo())
    .with_rule(@rule.no_duplicate_test_name())
    .with_rule(@rule.no_self_assignment())
    .with_rule(@rule.prefer_field_pun(), severity=Warning)
    .with_rule(@rule.prefer_label_pun(), severity=Warning)
  with_collections(config)
}
