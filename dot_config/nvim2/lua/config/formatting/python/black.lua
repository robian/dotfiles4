return {
  name = "black",
  formatter = "black",
  package = "black",
  markers = {},
  detect = function(context)
    return require("util.project").get(context.data, "tool", "black") ~= nil
  end,
}
