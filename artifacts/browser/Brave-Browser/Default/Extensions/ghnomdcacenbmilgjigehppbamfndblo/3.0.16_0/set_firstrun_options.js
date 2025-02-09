(function() {
  var out = {
    "error": null,
  };

  try {
    document.getElementById("camelizer_version").innerHTML = "3.0.16";
  } catch(e) {
    out["error"] = e.message + "\n" + e.stack;
  }

  return(out);
})();
