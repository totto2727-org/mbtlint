///|
pub fn prefer_collection_transfer() -> @core.Rule {
  collection_advice("prefer-collection-transfer", collection_build, operation => {
    match operation {
      TransferItems =>
        Some(
          "Consider an array copy or converting the iterator with to_array instead of pushing each item.",
        )
      _ => None
    }
  })
}
