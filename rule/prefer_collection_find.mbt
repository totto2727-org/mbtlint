///|
pub fn prefer_collection_find() -> @core.Rule {
  collection_advice("prefer-collection-find", collection_search, operation => {
    match operation {
      FindFirst =>
        Some("Consider Iter::find_first to return the first matching item.")
      _ => None
    }
  })
}
