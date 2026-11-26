///|
pub fn with_collections(config : @core.Config) -> @core.Config {
  config
  .with_rule(@rule.prefer_collection_map(), severity=Warning)
  .with_rule(@rule.prefer_collection_filter(), severity=Warning)
  .with_rule(@rule.prefer_collection_transfer(), severity=Warning)
  .with_rule(@rule.prefer_collection_any(), severity=Warning)
  .with_rule(@rule.prefer_collection_all(), severity=Warning)
  .with_rule(@rule.prefer_collection_find(), severity=Warning)
  .with_rule(@rule.prefer_collection_fold(), severity=Warning)
}
