///|
pub fn prefer_collection_any() -> @core.Rule {
  collection_advice("prefer-collection-any", collection_search, operation => {
    match operation {
      FindAny => Some("Consider any to test whether at least one item matches.")
      _ => None
    }
  })
}
