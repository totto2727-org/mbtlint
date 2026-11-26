///|
fn safety_is_unchecked_method(name : String, owner : String?) -> Bool {
  match name {
    "unsafe_get" =>
      owner is (None | Some("Array" | "MutArrayView" | "StringView"))
    "unsafe_set" | "unsafe_mut_view" =>
      owner is (None | Some("Array" | "MutArrayView")) ||
      (name == "unsafe_mut_view" && owner is Some("FixedArray"))
    "unsafe_view" =>
      owner
      is (None
      | Some(
        "Array"
        | "ArrayView"
        | "Bytes"
        | "BytesView"
        | "FixedArray"
        | "MutArrayView"
        | "ReadOnlyArray"
        | "String"
        | "StringView"
        | "UninitializedArray",
      ))
    "unsafe_range_equal" => owner is (None | Some("Bytes" | "String"))
    "unsafe_char_at" | "unsafe_substring" => owner is (None | Some("String"))
    "unsafe_charcode_at" => owner is (None | Some("StringView"))
    "unsafe_blit_fixed" => owner is (None | Some("Array"))
    "unsafe_blit"
    | "unsafe_write_uint16_be"
    | "unsafe_write_uint16_le"
    | "unsafe_write_uint32_be"
    | "unsafe_write_uint32_le"
    | "unsafe_write_uint64_be"
    | "unsafe_write_uint64_le" => owner is (None | Some("FixedArray"))
    "unsafe_tail" => owner is (None | Some("List"))
    "unsafe_from_string" => owner is (None | Some("Regex"))
    _ => false
  }
}

///|
/// Report calls to known unchecked core operations.
pub fn no_unsafe_operations() -> @core.Rule {
  builtin_rule("no-unsafe-operations", ctx => {
    safety_listener(ctx, expr => {
      let candidate = match expr {
        DotApply(method_name=label, ..) if safety_is_unchecked_method(
            label.name,
            None,
          ) => Some(label)
        _ =>
          match safety_callee(expr) {
            Some(Method(type_name={ name, .. }, method_name=label, ..)) =>
              if safety_core_owner(name) is Some(owner) &&
                safety_is_unchecked_method(label.name, Some(owner)) {
                Some(label)
              } else {
                None
              }
            _ => None
          }
      }
      if candidate is Some({ name, loc, }) {
        Some((loc, "Use a checked operation instead of \{name}."))
      } else {
        None
      }
    })
  })
}
