///|
/// Enable the opt-in MoonBit conventions rules.
pub fn with_conventions(config : @core.Config) -> @core.Config {
  config
  .with_rule(@rule.require_public_docs())
  .with_rule(@rule.prefer_labelled_parameters())
  .with_rule(@rule.prefer_arrow_callback())
  .with_rule(@rule.no_manual_path_join())
  .with_rule(@rule.require_named_tests())
  .with_rule(@rule.no_redundant_rethrow())
}
