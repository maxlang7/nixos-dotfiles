function read_storage(keys)
{
  
  try {
    var getting = browser.storage.sync.get(keys);
    return(getting);
  } catch (e) {
  }
  

  return(browser.storage.local.get(keys));
}

function write_storage(key, val)
{
  obj = {};
  obj[key] = val;
  browser.storage.local.set(obj);

  try {
    browser.storage.sync.set(obj);
  } catch (e) {  }
}

document.addEventListener('DOMContentLoaded', function() {
  const privlink = document.getElementById("privlink");
  if (privlink) {
    privlink.href = first_run_url() + "&reason=privacy";
  }

  read_storage(["browser_zoom", "window_size"]).then(function(data) {
    data["browser_zoom"] = data["browser_zoom"] || "1.0";

    
      var select = document.getElementById("browser_zoom");

      for (var i = 0; i < select.options.length; i++)
      {
        var opt = select.options[i];
        opt.selected = parseFloat(opt.value) == parseFloat(data["browser_zoom"]);
      }

      select.addEventListener("change", function (e) {
        var browser_zoom = e.currentTarget.value;
        write_storage("browser_zoom", browser_zoom);
      });
    

    data["window_size"] = data["window_size"] || "default";

    $("#windowsize_" + data["window_size"]).prop("checked", true);

    $("input[name='windowsize']").change(function (e) {
      var elm = $(e.currentTarget);
      if (elm.prop("checked")) {
        write_storage("window_size", elm.val());
      }
    });
  });
});