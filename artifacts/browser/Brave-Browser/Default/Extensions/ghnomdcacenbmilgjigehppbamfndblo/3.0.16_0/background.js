function on_tab_activated(active_info)
{
  browser.tabs.query({active: true, currentWindow: true}).then(function(tab) {
    tab = tab[0];
    check_for_valid_url(active_info.tabId, {}, tab); 
  }, function(err) {
    dmsg("Error");
    dmsg(err);
    // show some error msg
  });
}

function check_for_valid_url(tab_id, change_info, tab)
{
  url = tab.url;
  
  // special case for the first_run page on our site
  if (url && url.indexOf("/camelizer/first_run") != -1)
  {
    dmsg("FIRST RUN!");
    
    set_firstrun_options(function() {
      dmsg("set firstrun options");
      dmsg(arguments);
    });
    
    //camelizer_pageview("/first_run");
  }
  
  var is_c = url && is_camel(url);

  
  if (is_c)
    announce(function() {});
  
  // a popup-based UI for amazon, and a shortcut back to amazon when on a camelcamelcamel page
  browser.pageAction.setPopup({"tabId": tab_id, "popup": is_c ? "camel.html" : "main.html"});
  
}

browser.runtime.onInstalled.addListener(function(obj) {
  dmsg("INSTALLED");
  dmsg(obj);
  
  load_settings(function() {
    // port over old settings if they exist, then delete em
    var pairs = new Object({
      "date_range": "period",
      "close_up_view": "close_up",
      "remove_extreme_values": "filter_outliers",
      "pt_amazon": "price_types",
      "pt_new": "price_types",
      "pt_used": "price_types",
    });
    
    var v2_keys = Object.keys(pairs);
    dmsg(v2_keys);
    
    DataStore.get(v2_keys).then(function(data) {
      dmsg("v2 keys!");
      Object.entries(data).forEach(function (e) {
        var k = e[0];
        var v = e[1]
        var v3_key = pairs[k];
        
        if (v3_key == "price_types")
        {
          var pt_less_type = k.split("_")[1];
          
          if (v)
            CAMELIZER.enable_price_type(pt_less_type);
          else
            CAMELIZER.disable_price_type(pt_less_type);
        }
        else
          CAMELIZER.setting(v3_key, v);
      });
      
      save_settings();
      
      dmsg("REMOVING");
      dmsg(v2_keys);
      DataStore.remove(v2_keys);

      camelizer_event("Install", obj.reason, null);

      if (obj.reason == "install" || (obj.reason == "update" && CAMELIZER.is_camelizer_three_oh_oh()))
      {
        var tab = null;
        var args = {
          url: (first_run_url() + "&reason=" + obj.reason),
          active: true,
        };
        
        browser.tabs.create(args).then(function(tab) {
          tab = tab;
          tab.url = args.url;
        }, function(e) {
          dmsg("ERROR CREATING FIRST RUN");
          dmsg(e);
        });
      }
    });
  });
});

browser.runtime.setUninstallURL(last_run_url());


browser.tabs.onUpdated.addListener(check_for_valid_url);
browser.tabs.onActivated.addListener(on_tab_activated);

