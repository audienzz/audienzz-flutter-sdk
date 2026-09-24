# Audienzz clickstream analytics — field contract

The contract is cross-platform and is maintained in one place, in the Android SDK repository:

**`audienzz-android-sdk/docs/analytics-contract.md`**

It covers field provenance, types, units, nullability, event scope and release compatibility for
all four SDKs. Duplicating it here would only let the copies drift.

Two things worth knowing without opening it:

* **Every value inside `attributes` is a JSON string**, including numeric-looking ones such as
  `slot_reload`, `cpm` and `time_to_respond`.
* **This bridge emits no analytics events of its own.** Everything comes from the native SDK, which
  is why `source` is `android-sdk` or `ios-sdk` and not the wrapper framework. See §8 of the
  contract for the additive-metadata proposal if you need to tell them apart.
