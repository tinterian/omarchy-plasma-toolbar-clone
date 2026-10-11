-- spencer.bar: blur behind the floating bar only. Blur is a global switch, so
-- turn it on, exclude windows (every window runs at ~0.98 opacity and would
-- otherwise get backdrop blur too), and blur just the omarchy-bar layer.
-- ignore_alpha keeps fully transparent pixels (the floating gap) unblurred.
-- The bar's "Blur intensity" slider sets decoration.blur.size at runtime.
hl.config({
  decoration = {
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
    },
  },
})
o.window(".*", { no_blur = true })
hl.layer_rule({ match = { namespace = "omarchy-bar" }, blur = true, ignore_alpha = 0 })
