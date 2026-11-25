///|
pub fn prefer_collection_filter() -> @core.Rule {
  collection_advice("prefer-collection-filter", collection_build, operation => {
    match operation {
      FilterItems =>
        Some("Consider filter to keep the items that pass this condition.")
      FilterMapItems =>
        Some("Consider filter_map to keep and transform items in one pass.")
      _ => None
    }
  })
}
