///|
priv enum CollectionOperation {
  MapItems
  FilterItems
  FilterMapItems
  TransferItems
  FindAny
  CheckAll
  FindFirst
}

///|
fn collection_unwrap(expr : @syntax.Expr) -> @syntax.Expr {
  match expr {
    Group(expr~, ..) => collection_unwrap(expr)
    _ => expr
  }
}

///|
fn collection_name(expr : @syntax.Expr) -> String? {
  match collection_unwrap(expr) {
    Ident(id={ name: Ident(name~), .. }, ..) => Some(name)
    _ => None
  }
}

///|
fn collection_source(expr : @syntax.Expr, excluded : String?) -> Bool {
  match collection_unwrap(expr) {
    Ident(..) => excluded is None || collection_name(expr) != excluded
    DotApply(
      self~,
      method_name={ name: "iter", .. },
      args=Empty,
      return_self=false,
      ..
    ) => collection_source(self, excluded)
    Array(..) | ArraySpread(..) => collection_callback(expr, excluded)
    _ => false
  }
}

///|
fn collection_callback(expr : @syntax.Expr, excluded : String?) -> Bool {
  let permitted = item => collection_callback(item, excluded)
  let permitted_arg = (arg : @syntax.Argument) => permitted(arg.value)
  match collection_unwrap(expr) {
    Constant(..) | Constr(..) => true
    Ident(..) => excluded is None || collection_name(expr) != excluded
    Array(exprs~, ..) | Tuple(exprs~, ..) => exprs.all(permitted)
    ArraySpread(elems~, ..) =>
      elems.all(elem => {
        match elem {
          Regular(expr) | Spread(expr~, ..) => permitted(expr)
        }
      })
    Infix(lhs~, rhs~, ..) | ArrayGet(array=lhs, index=rhs, ..) =>
      permitted(lhs) && permitted(rhs)
    Unary(expr~, ..) | Constraint(expr~, ..) | Field(record=expr, ..) =>
      permitted(expr)
    Apply(func~, args~, ..) if collection_unwrap(func)
      is (Ident(..) | Constr(..)) => permitted(func) && args.all(permitted_arg)
    DotApply(self~, args~, return_self=false, ..) =>
      permitted(self) && args.all(permitted_arg)
    _ => false
  }
}

///|
fn collection_push(expr : @syntax.Expr, target : String) -> @syntax.Expr? {
  match collection_unwrap(expr) {
    DotApply(
      self~,
      method_name={ name: "push", .. },
      args=More({ kind: Positional, value, }, tail=Empty),
      return_self=false,
      ..
    ) if collection_name(self) == Some(target) => Some(value)
    _ => None
  }
}

///|
fn collection_build(
  expr : @syntax.Expr,
  advice : (CollectionOperation) -> String?,
) -> (String, @basic.Location)? {
  guard expr is Let(pattern~, expr=seed, body=sequence, ..) else { return None }
  let target = match pattern {
    Var(binder) | Constraint(pat=Var(binder), ..) => binder.name
    _ => return None
  }
  guard collection_unwrap(seed) is Array(exprs=Empty, is_iter=false, ..) else {
    return None
  }
  guard sequence is Sequence(exprs=More(iteration, tail=Empty), last_expr~, ..) &&
    collection_name(last_expr) == Some(target) else {
    return None
  }
  guard collection_unwrap(iteration)
    is ForEach(
      patterns=More(Var(item), tail=Empty),
      expr=source,
      init=Empty,
      continue_block=Empty,
      body~,
      else_block=None,
      where_clause=None,
      label=None,
      loc~,
    ) &&
    item.name != target else {
    return None
  }
  let (step, condition) = match collection_unwrap(body) {
    If(cond~, ifso~, ifnot=None, ..) => (ifso, Some(cond))
    step => (step, None)
  }
  guard collection_push(step, target) is Some(value) else { return None }
  let identity = collection_name(value) == Some(item.name)
  let kind = match (condition, identity) {
    (None, true) => TransferItems
    (None, false) => MapItems
    (Some(_), true) => FilterItems
    (Some(_), false) => FilterMapItems
  }
  guard advice(kind) is Some(message) &&
    collection_source(source, Some(target)) &&
    collection_callback(value, Some(target)) else {
    return None
  }
  if condition is Some(cond) && !collection_callback(cond, Some(target)) {
    return None
  }
  Some((message, loc))
}

///|
fn collection_search(
  expr : @syntax.Expr,
  advice : (CollectionOperation) -> String?,
) -> (String, @basic.Location)? {
  guard expr
    is ForEach(
      patterns=More(Var(item), tail=Empty),
      expr=source,
      init=Empty,
      continue_block=Empty,
      body~,
      else_block=Some(fallback),
      where_clause=None,
      label=None,
      loc~,
    ) else {
    return None
  }
  guard collection_unwrap(body) is If(cond~, ifso~, ifnot=None, ..) else {
    return None
  }
  guard collection_unwrap(ifso) is Break(arg=Some(hit), label=None, ..) else {
    return None
  }
  let kind = match (collection_unwrap(hit), collection_unwrap(fallback)) {
    (Constant(c=Bool(true), ..), Constant(c=Bool(false), ..)) => FindAny
    (Constant(c=Bool(false), ..), Constant(c=Bool(true), ..)) => CheckAll
    (
      Apply(
        func=Constr(
          constr={ name: { name: "Some", .. }, extra_info: NoExtraInfo, .. },
          ..
        ),
        args=More({ kind: Positional, value, }, tail=Empty),
        ..
      ),
      Constr(
        constr={ name: { name: "None", .. }, extra_info: NoExtraInfo, .. },
        ..
      ),
    ) if collection_name(value) == Some(item.name) => FindFirst
    _ => return None
  }
  guard advice(kind) is Some(message) &&
    collection_source(source, None) &&
    collection_callback(cond, None) else {
    return None
  }
  Some((message, loc))
}

///|
fn collection_fold_update(expr : @syntax.Expr, accumulator : String) -> Bool {
  match collection_unwrap(expr) {
    Infix(lhs~, rhs~, ..) =>
      collection_name(lhs) == Some(accumulator) &&
      collection_callback(rhs, Some(accumulator))
    _ => false
  }
}

///|
fn collection_fold(expr : @syntax.Expr) -> @basic.Location? {
  match expr {
    ForEach(
      patterns=More(Var(item), tail=Empty),
      expr=source,
      init=More((acc, _), tail=Empty),
      continue_block=Empty,
      body~,
      else_block=Some(last),
      where_clause=None,
      label=None,
      loc~,
    ) if item.name != acc.name &&
      collection_source(source, Some(acc.name)) &&
      collection_name(last) == Some(acc.name) =>
      match collection_unwrap(body) {
        Continue(args=More(step, tail=Empty), label=None, ..) if collection_fold_update(
            step,
            acc.name,
          ) => Some(loc)
        _ => None
      }
    LetMut(
      binder=acc,
      body=Sequence(exprs=More(iteration, tail=Empty), last_expr~, ..),
      ..
    ) if collection_name(last_expr) == Some(acc.name) => {
      guard collection_unwrap(iteration)
        is ForEach(
          patterns=More(Var(item), tail=Empty),
          expr=source,
          init=Empty,
          continue_block=Empty,
          body~,
          else_block=None,
          where_clause=None,
          label=None,
          loc~,
        ) &&
        item.name != acc.name &&
        collection_source(source, Some(acc.name)) else {
        return None
      }
      guard collection_unwrap(body)
        is Assign(var_={ name: Ident(name~), .. }, expr=step, augmented_by~, ..) &&
        name == acc.name else {
        return None
      }
      let eligible = match augmented_by {
        Some(_) => collection_callback(step, Some(acc.name))
        None => collection_fold_update(step, acc.name)
      }
      if eligible {
        Some(loc)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn collection_advice(
  id : String,
  classify : (@syntax.Expr, (CollectionOperation) -> String?) -> (
    String,
    @basic.Location,
  )?,
  advice : (CollectionOperation) -> String?,
) -> Rule {
  builtin_rule(id, ctx => {
    Listener(on_expr=expr => {
      if classify(expr, advice) is Some((message, loc)) {
        (ctx.report)(loc, message)
      }
    })
  })
}

///|
pub fn prefer_collection_map() -> Rule {
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

///|
pub fn prefer_collection_filter() -> Rule {
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

///|
pub fn prefer_collection_transfer() -> Rule {
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

///|
pub fn prefer_collection_any() -> Rule {
  collection_advice("prefer-collection-any", collection_search, operation => {
    match operation {
      FindAny => Some("Consider any to test whether at least one item matches.")
      _ => None
    }
  })
}

///|
pub fn prefer_collection_all() -> Rule {
  collection_advice("prefer-collection-all", collection_search, operation => {
    match operation {
      CheckAll =>
        Some("Consider all with the negation of this break condition.")
      _ => None
    }
  })
}

///|
pub fn prefer_collection_find() -> Rule {
  collection_advice("prefer-collection-find", collection_search, operation => {
    match operation {
      FindFirst =>
        Some("Consider Iter::find_first to return the first matching item.")
      _ => None
    }
  })
}

///|
pub fn prefer_collection_fold() -> Rule {
  builtin_rule("prefer-collection-fold", ctx => {
    Listener(on_expr=expr => {
      if collection_fold(expr) is Some(loc) {
        (ctx.report)(
          loc, "Consider fold to compute this accumulator from the items in order.",
        )
      }
    })
  })
}

///|
pub fn Config::with_collections(self : Config) -> Config {
  self
  .with_rule(prefer_collection_map(), severity=Warning)
  .with_rule(prefer_collection_filter(), severity=Warning)
  .with_rule(prefer_collection_transfer(), severity=Warning)
  .with_rule(prefer_collection_any(), severity=Warning)
  .with_rule(prefer_collection_all(), severity=Warning)
  .with_rule(prefer_collection_find(), severity=Warning)
  .with_rule(prefer_collection_fold(), severity=Warning)
}
