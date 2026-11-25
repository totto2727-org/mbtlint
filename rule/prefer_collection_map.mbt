///|
pub fn prefer_collection_map() -> @core.Rule {
  collection_advice("prefer-collection-map", collection_build, operation => {
    match operation {
      MapItems =>
        Some(
          "Consider map to build the result from one transformed value per item.",
        )
      _ => None
    }
  })
}
