///|
pub fn prefer_collection_all() -> @core.Rule {
  collection_advice("prefer-collection-all", collection_search, operation => {
    match operation {
      CheckAll =>
        Some("Consider all with the negation of this break condition.")
      _ => None
    }
  })
}
