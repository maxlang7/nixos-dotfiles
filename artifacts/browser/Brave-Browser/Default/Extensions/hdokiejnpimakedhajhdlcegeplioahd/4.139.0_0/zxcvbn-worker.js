var WORKER_MESSAGE_COMPUTE_PW_SCORE = 'compute_password_strength';
var WORKER_MESSAGE_COMPUTE_PW_SCORE_RESULT = 'compute_password_strength_result';

if (typeof importScripts === "function") {
      var isSPA = location.pathname.startsWith('/vault/')

      if (location.protocol == "https:" && !isSPA) {
        // load scripts in web
        importScripts("/js-thirdparty/zxcvbn.js");
        importScripts("/js-thirdparty/zxcvbn-ts-core.min.js");
        importScripts("/js-thirdparty/zxcvbn-ts-language-common.js");
        importScripts("/js-thirdparty/zxcvbn-ts-language-en.js");
        importScripts("/js-thirdparty/zxcvbn-ts-language-de.js");
        importScripts("/js-thirdparty/zxcvbn-ts-language-es-es.js");
        importScripts("/js-thirdparty/zxcvbn-ts-language-fr.js");
        importScripts("/js-thirdparty/zxcvbn-ts-language-it.js");
        importScripts("/js-thirdparty/zxcvbn-ts-language-nl-be.js");
        importScripts("/js-thirdparty/zxcvbn-ts-language-pt-br.js");
        importScripts("/js/sjcl/sjcl.js");
        importScripts("/js/sha256.js");
      } else {
        // load scripts in extension
        var baseUrl = location.pathname.slice(0, -26);

        // In case of SPA we included them in the bundle
        if (isSPA) {
          baseUrl = '/vault';
        }

        importScripts(baseUrl + "/zxcvbn.js");
        importScripts(baseUrl + "/zxcvbn-ts.js");
        importScripts(baseUrl + "/zxcvbn-ts-language-common.js");
        importScripts(baseUrl + "/zxcvbn-ts-language-en.js");
        importScripts(baseUrl + "/zxcvbn-ts-language-de.js");
        importScripts(baseUrl + "/zxcvbn-ts-language-es-es.js");
        importScripts(baseUrl + "/zxcvbn-ts-language-fr.js");
        importScripts(baseUrl + "/zxcvbn-ts-language-it.js");
        importScripts(baseUrl + "/zxcvbn-ts-language-nl-be.js");
        importScripts(baseUrl + "/zxcvbn-ts-language-pt-br.js");
        importScripts(baseUrl + "/sjcl.js");
        importScripts(baseUrl + "/sha256.js");
    }
    var startTime;
    var LEVENSHTEIN_DEFAULT = false;
    var LEVENSHTEIN_VAULT_SIZE_LIMIT = 200;
    var useLevenshteinDistance = LEVENSHTEIN_DEFAULT;

  function isVaultOverLevenshteinLimit(sites) {
    return sites.length < LEVENSHTEIN_VAULT_SIZE_LIMIT;
  }

  function addToDictionary (zxcvbntsdictionary, addition) {
    Object.keys(addition).forEach(function (key) {
      if (!zxcvbntsdictionary[key]) {
        zxcvbntsdictionary[key] = addition[key];
      } else {
        zxcvbntsdictionary[key].concat(addition[key]);
      }
    });
  }

  function setupZXCVBN (useLevenshtein) {
    var zxcvbntsDictionary = {};

    addToDictionary(zxcvbntsDictionary, zxcvbnts["language-common"].dictionary);
    addToDictionary(zxcvbntsDictionary, zxcvbnts["language-en"].dictionary);
    addToDictionary(zxcvbntsDictionary, zxcvbnts["language-de"].dictionary);
    addToDictionary(zxcvbntsDictionary, zxcvbnts["language-es-es"].dictionary);
    addToDictionary(zxcvbntsDictionary, zxcvbnts["language-fr"].dictionary);
    addToDictionary(zxcvbntsDictionary, zxcvbnts["language-it"].dictionary);
    addToDictionary(zxcvbntsDictionary, zxcvbnts["language-nl-be"].dictionary);
    addToDictionary(zxcvbntsDictionary, zxcvbnts["language-pt-br"].dictionary);

    var zxcvbntsOptions = {
      useLevenshteinDistance: useLevenshtein,
      translations: zxcvbnts['language-en'].translations,
      graphs: zxcvbnts['language-common'].adjacencyGraphs,
      dictionary: zxcvbntsDictionary
    };

    zxcvbnts.core.zxcvbnOptions.setOptions(zxcvbntsOptions);
    useLevenshteinDistance = useLevenshtein;
  }
  function handleSecurityScoreCalculation(e) {
    startTime = new Date().getTime();
    setupZXCVBN(!isVaultOverLevenshteinLimit(e.data.g_aSites));
    challengecomputescore_async(
      e.data.curr,
      e.data.g_totalscore,
      JSON.parse(e.data.g_sites),
      e.data.g_aSites && e.data.g_aSites.length ? e.data.g_aSites : [],
      e.data.g_numsites,
      e.data.g_numblanksites,
      e.data.g_avgpasswordlength,
      e.data.g_aPasswords,
      e.data.g_MAXNUMCOMPUTESCORE,
      e.data.g_numduppasswords,
      e.data.g_numdupsites,
      e.data.g_usernames,
      e.data.WEAKPASSWORDSCORE,
      e.data.g_strengthscore,
      e.data.g_countscore,
      e.data.g_numweak,
      e.data.sharedavgstrength,
      e.data.SharedAccounts,
      e.data.g_runtimems,
      e.data.sfcounts,
      e.data.sharedstrengthscore,
      e.data.sharedblanksites,
      e.data.sharedweak,
      e.data.sharedavgpasswordlength,
      e.data.SharedPasswords,
      e.data.sharedcountscore,
      e.data.NonSharedAccounts,
      e.data.g_SFNames,
      e.data.AllSFNames,
      e.data.sharedtotalscore,
      e.data.g_numvulnerablesites,
      e.data.g_allPasswords,
      e.data.g_reuse,
      e.data.g_blanksites,
      e.data.g_allnumduppasswords,
      e.data.equivalentDomainCheckList,
      e.data.isExcludeSwitchedOn,
      e.data.excludedPasswords,
      e.data.domainsForAutomaticPasswordExclude,
      e.data.isFeatureEnabledSecurityDashboard2_0,
      e.data.dwmAlerts,
      e.data.SFNameToID,
      e.data.AIDtoSFNames,
      e.data.AllSFIDs,
      e.data.g_myaccounts,
      e.data.g_avgstrength
    );
  }

  onmessage = function (e) {
    if (
      e.data.source === "zxcvbn" &&
      e.data.cmd === "challengecomputescore_async"
    ) {
      handleSecurityScoreCalculation(e);
    }
    if(e.data.cmd === WORKER_MESSAGE_COMPUTE_PW_SCORE){
      if(typeof e.data.useLevenshteinDistance === "undefined" && useLevenshteinDistance !== LEVENSHTEIN_DEFAULT){
        setupZXCVBN(LEVENSHTEIN_DEFAULT);
      } else if(typeof e.data.useLevenshteinDistance !== "undefined" &&
        e.data.useLevenshteinDistance !== useLevenshteinDistance) {
        setupZXCVBN(e.data.useLevenshteinDistance);
      }
      var result = challengegetstrength(e.data.username, e.data.password);
      postMessage({cmd: WORKER_MESSAGE_COMPUTE_PW_SCORE_RESULT, result: result, password: lp_sha2lib.sha256(e.data.password)});
    }
  };

  setupZXCVBN(LEVENSHTEIN_DEFAULT);

  // zxcvbn's method returns a number between 0-4, 25 is the multiplier to produce the score as percentage
  function challengegetstrength(username, password) {
    var CHALLENGE_SCORE_MULTIPLIER = 25;
    return calculatePasswordStrength(password, username) * CHALLENGE_SCORE_MULTIPLIER
  }

  function calculatePasswordStrength(password, username) {
    if (typeof zxcvbnts === "undefined") {
      throw new Error("No zxcvbn functionality available");
    }
    var whitespaceRegex = /\s/g;
    var passwordStr = password ? password.substring(0, 50).replace(whitespaceRegex, "") : "";
    var usernameStr = username ? username.substring(0, 50).toLowerCase() : "";
    var result = zxcvbnts.core.zxcvbn(passwordStr, [
      usernameStr,
      "lastpass",
      "lastpass.com",
    ]);

    return result.score;
  }
  function challengecomputescore_async(
    curr,
    g_totalscore,
    g_sites,
    g_aSites,
    g_numsites,
    g_numblanksites,
    g_avgpasswordlength,
    g_aPasswords,
    g_MAXNUMCOMPUTESCORE,
    g_numduppasswords,
    g_numdupsites,
    g_usernames,
    WEAKPASSWORDSCORE,
    g_strengthscore,
    g_countscore,
    g_numweak,
    sharedavgstrength,
    SharedAccounts,
    g_runtimems,
    sfcounts,
    sharedstrengthscore,
    sharedblanksites,
    sharedweak,
    sharedavgpasswordlength,
    SharedPasswords,
    sharedcountscore,
    NonSharedAccounts,
    g_SFNames,
    AllSFNames,
    sharedtotalscore,
    g_numvulnerablesites,
    g_allPasswords,
    g_reuse,
    g_blanksites,
    g_allnumduppasswords,
    equvialentDomainCheckList,
    isExcludeSwitchedOn,
    excludedPasswords,
    domainsForAutomaticPasswordExclude,
    isFeatureEnabledSecurityDashboard2_0,
    dwmAlerts,
    SFNameToID,
    AIDtoSFNames,
    AllSFIDs,
    g_myaccounts,
    g_avgstrength
  ) {
    function sendPostMessage() {
      var reportMessage = {
        cmd: "report",
        runtimesec:
          typeof runtimesec !== "undefined"
            ? runtimesec
            : undefined,
        calcTimeMs:
          typeof startTime !== "undefined"
            ? new Date().getTime() - startTime
            : undefined,
        g_totalscore:
          typeof g_totalscore !== "undefined"
            ? g_totalscore
            : undefined,
        g_aSites:
          typeof g_aSites !== "undefined" ? g_aSites : undefined,
        g_numsites:
          typeof g_numsites !== "undefined" ? g_numsites : 0,
        g_numblanksites:
          typeof g_numblanksites !== "undefined"
            ? g_numblanksites
            : 0,
        g_avgpasswordlength:
          typeof g_avgpasswordlength !== "undefined"
            ? g_avgpasswordlength
            : 0,
        g_avgstrength :
          typeof g_avgstrength !== "undefined"
            ? g_avgstrength
            : 0,
        g_aPasswords:
          typeof g_aPasswords !== "undefined" ? g_aPasswords : {},
        g_MAXNUMCOMPUTESCORE:
          typeof g_MAXNUMCOMPUTESCORE !== "undefined"
            ? g_MAXNUMCOMPUTESCORE
            : 0,
        g_numduppasswords:
          typeof g_numduppasswords !== "undefined"
            ? g_numduppasswords
            : 0,
        g_numdupsites:
          typeof g_numdupsites !== "undefined"
            ? g_numdupsites
            : 0,
        g_usernames:
          typeof g_usernames !== "undefined" ? g_usernames : [],
        WEAKPASSWORDSCORE:
          typeof WEAKPASSWORDSCORE !== "undefined"
            ? WEAKPASSWORDSCORE
            : 50,
        g_strengthscore:
          typeof g_strengthscore !== "undefined"
            ? g_strengthscore
            : 0,
        g_countscore:
          typeof g_countscore !== "undefined" ? g_countscore : 0,
        g_numweak: typeof g_numweak !== "undefined" ? g_numweak : 0,
        sharedavgstrength:
          typeof sharedavgstrength !== "undefined"
            ? sharedavgstrength
            : [],
        SharedAccounts:
          typeof SharedAccounts !== "undefined"
            ? SharedAccounts
            : [],
        g_runtimems:
          typeof g_runtimems !== "undefined" ? g_runtimems : 0,
        sfcounts: typeof sfcounts !== "undefined" ? sfcounts : [],
        sharedstrengthscore:
          typeof sharedstrengthscore !== "undefined"
            ? sharedstrengthscore
            : [],
        sharedblanksites:
          typeof sharedblanksites !== "undefined"
            ? sharedblanksites
            : [],
        sharedweak:
          typeof sharedweak !== "undefined" ? sharedweak : [],
        sharedavgpasswordlength:
          typeof sharedavgpasswordlength !== "undefined"
            ? sharedavgpasswordlength
            : [],
        SharedPasswords:
          typeof SharedPasswords !== "undefined"
            ? SharedPasswords
            : [],
        sharedcountscore:
          typeof sharedcountscore !== "undefined"
            ? sharedcountscore
            : [],
        NonSharedAccounts:
          typeof NonSharedAccounts !== "undefined"
            ? NonSharedAccounts
            : [],
        g_SFNames:
          typeof g_SFNames !== "undefined" ? g_SFNames : [],
        AllSFNames:
          typeof AllSFNames !== "undefined" ? AllSFNames : [],
        sharedtotalscore:
          typeof sharedtotalscore !== "undefined"
            ? sharedtotalscore
            : [],
        g_numvulnerablesites:
          typeof g_numvulnerablesites !== "undefined"
            ? g_numvulnerablesites
            : 0,
        g_allPasswords:
          typeof g_allPasswords !== "undefined"
            ? g_allPasswords
            : {},
        g_reuse:
          typeof g_reuse !== "undefined" ? g_reuse : undefined,
        g_blanksites:
          typeof g_blanksites !== "undefined"
            ? g_blanksites
            : undefined,
        g_allnumduppasswords:
          typeof g_allnumduppasswords !== "undefined"
            ? g_allnumduppasswords
            : 0,
      };
      reportMessage["report"] = createReport(reportMessage);
      postMessage(reportMessage);
    }

    function createReport(reportMessage){
      var result = { totalscore: reportMessage.g_totalscore,
        numblanksites: reportMessage.g_numblanksites,
        numvulnerablesites: reportMessage.g_numvulnerablesites,
        numduppasswords: reportMessage.g_numduppasswords,
        numallduppasswords: reportMessage.g_allnumduppasswords,
        numdupsites: reportMessage.g_numdupsites,
        numalldupsites: 0,
        numweak: reportMessage.g_numweak,
        avgstrength:reportMessage.g_avgstrength,
        countscore: reportMessage.g_countscore }

      //JSON.parse(JSON.stringify(reportMessage));

      var numdup = 0;
      var pass;
      for(pass in g_allPasswords){
        if(!g_allPasswords.hasOwnProperty(pass)) continue;
        var dupsites = "";
        for(var j in g_allPasswords[pass]){
          if(!g_allPasswords[pass].hasOwnProperty(j)) continue;
          var domain =  g_allPasswords[pass][j];
          for(var k in domain){
            if(!domain.hasOwnProperty(k)) continue;
            var tmpid=SFNameToID[AIDtoSFNames[g_aSites[domain[k]]["id"]]];
            if (typeof(tmpid)=='undefined') tmpid='NotShared';
            dupsites += tmpid+':'+g_aSites[domain[k]]["id"] + ",";
          }
        }
        result["dupsites_global_"+numdup] = dupsites;
        numdup++;
      }
      // Clean memory
      pass = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

      //Add information about weak passwords
      var weak = "";
      for(var i = 0; i < g_aSites.length; i++){
        if(typeof(g_aSites[i]['challenge_scorefinal'])!='undefined' && (typeof(g_aSites[i]['sfname'])=='undefined' || g_aSites[i]['sfname']=='nonshared') && parseInt(g_aSites[i]['challenge_scorefinal']) < WEAKPASSWORDSCORE){
          weak += g_aSites[i]['id'] + ":" + g_aSites[i]['challenge_scorefinal'].toFixed(2) + ",";
        }

      }
      result["weak"] = weak;


      var SFScores=[];
      var SFIDs=[];

      for( var i = 0; i < AllSFNames.length; i++) {
        var sfname = AllSFNames[i];
        var mysfid = SFNameToID[sfname];
        SFIDs[i] = mysfid;
        result[mysfid+'_sfname']=sfname; // - Only needed when debugging.
        result[mysfid+'_totalscore']=sharedtotalscore[sfname];
        result[mysfid+'_numaccts']=SharedAccounts[sfname] ? SharedAccounts[sfname].length : 0;
        result[mysfid+'_numblanksites']=sharedblanksites[sfname];
        result[mysfid+'_numweak']=sharedweak[sfname];
        result[mysfid+'_avgstrength']=sharedavgstrength[sfname];
        result[mysfid+'_countscore']=sharedcountscore[sfname];
      }

      result["SFIDs"]=SFIDs;
      result["AllSFIDs"]=AllSFIDs;
      result["SFScores"]=SFScores;
      result['SharedFolderList']=AllSFNames;
      result['my_accts']=g_myaccounts.length;

      return result;
    }

    if (g_totalscore !== 0) {
      sendPostMessage();
      return;
    }

    var i = typeof curr == "undefined" ? 0 : curr;
    var numsites = 0;
    var sfname;
    equvialentDomainCheckList = typeof equvialentDomainCheckList === 'undefined' ? {} : equvialentDomainCheckList;

    if (
      typeof g_aSites[i] != "undefined" &&
      typeof g_aSites[i]["sfname"] != "undefined"
    )
      sfname = g_aSites[i]["sfname"];
    if (typeof sfname == "undefined") sfname = "nonshared";

    //The follow bits are needed to jive with online challenge as well as local.
    if (typeof sfcounts == "undefined") sfcounts = [];
    if (typeof sharedstrengthscore == "undefined")
      sharedstrengthscore = [];
    if (typeof sharedblanksites == "undefined") sharedblanksites = [];
    if (typeof sharedweak == "undefined") sharedweak = [];
    if (typeof sharedavgpasswordlength == "undefined")
      sharedavgpasswordlength = [];
    if (typeof SharedPasswords == "undefined") SharedPasswords = [];
    if (typeof sharedcountscore == "undefined") sharedcountscore = [];
    if (typeof NonSharedAccounts == "undefined") NonSharedAccounts = [];
    if (typeof g_SFNames == "undefined") g_SFNames = [];
    if (typeof AllSFNames == "undefined") AllSFNames = [];

    if (typeof sfcounts[sfname] == "undefined") sfcounts[sfname] = 0;

    sfcounts[sfname]++;

    if (typeof curr == "undefined") g_challengeregexcache = [];
    for (; i < g_numsites; ++i) {
      if (typeof reportprogress == "function") {
        reportprogress(i, g_numsites);
      }

      sfname = "nonshared";
      if (typeof g_aSites[i]["sfname"] != "undefined")
        var sfname = g_aSites[i]["sfname"];
      var username = g_aSites[i]["usernamedec"];
      var password = g_aSites[i]["passworddec"];
      if (!password) {
        password = "";
      }
      var passwordfix = g_aSites[i]["passworddecfix"];
      var domain2lvl = g_aSites[i]["domain2lvl"];
      var realdomain2lvl =
        typeof g_aSites[i]["realdomain2lvl"] != "undefined"
          ? g_aSites[i]["realdomain2lvl"]
          : domain2lvl;
      var isvulnerable =
        typeof g_aSites[i]["vulnerable"] != "undefined"
          ? true
          : false;

      if (typeof g_numblanksites == "undefined") g_numblanksites = 0;
      if (typeof g_numvulnerablesites == "undefined")
        g_numvulnerablesites = 0;
      if (typeof sharedblanksites[sfname] == "undefined")
        sharedblanksites[sfname] = 0;
      if (typeof sharedstrengthscore[sfname] == "undefined")
        sharedstrengthscore[sfname] = 0;

      // Calculate raw strength
      var sitepwlen =
        typeof get_sitepwlen == "function"
          ? get_sitepwlen(realdomain2lvl)
          : 1;

      var isExcludedBySite = excludedPasswords &&
        Object.values(excludedPasswords).indexOf(g_aSites[i].id) !== -1;

      if (isvulnerable) {
        if (sfname == "nonshared") ++g_numvulnerablesites;
        //sharedvulnerablesites[sfname]++; TODO
        g_aSites[i]["challenge_score"] = 0;
      } else if (password.length > 0 && password.length < sitepwlen) {
        g_aSites[i]["challenge_score"] = 0;
      } else {
        g_aSites[i]["challenge_score"] = challengegetstrength(
          username,
          password
        );

        var isExcludedByDomain = domainsForAutomaticPasswordExclude &&
          Object.values(domainsForAutomaticPasswordExclude).indexOf(g_aSites[i].realdomain2lvl) !== -1;

        if (isExcludeSwitchedOn && (isExcludedByDomain || isExcludedBySite)) {
          g_aSites[i]["is_excluded"] = true;
        }
      }

      if (passwordfix == "") {
        if (sfname == "nonshared") g_numblanksites++;
        sharedblanksites[sfname]++;
        if (typeof g_blanksites !== "undefined")
          g_blanksites.push(i);
        // Clean memory
        username =
          "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        password =
          "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        passwordfix =
          "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        continue;
      }

      // Calculate avg password length
      if (sfname == "nonshared")
        g_avgpasswordlength += password.length;
      if (typeof sharedavgpasswordlength[sfname] == "undefined")
        sharedavgpasswordlength[sfname] = 0;
      sharedavgpasswordlength[sfname] += password.length;

      // Make a list of all passwords and who they belong to -- treat duplicates only if different 2nd level domain
      if (typeof SharedPasswords[sfname] == "undefined")
        SharedPasswords[sfname] = [];

      if (sfname == "nonshared" && !isExcludedBySite) {
        if (typeof g_aPasswords[passwordfix] == "undefined")
          g_aPasswords[passwordfix] = [];
        if (
          typeof g_aPasswords[passwordfix][domain2lvl] ==
          "undefined" ||
          (typeof g_aPasswords[passwordfix][domain2lvl] ==
            "function" &&
            typeof g_aPasswords[passwordfix][domain2lvl].push ==
            "undefined")
        )
          g_aPasswords[passwordfix][domain2lvl] = [];
        try {
          g_aPasswords[passwordfix][domain2lvl].push(i);
        } catch (e) {
          // Clean memory
          username =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          password =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          passwordfix =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          return;
        }
      }

      if (typeof g_allPasswords == "undefined") g_allPasswords = [];

      if (!isExcludedBySite) {
        if (typeof g_allPasswords[passwordfix] == "undefined") {
          g_allPasswords[passwordfix] = [];
          equvialentDomainCheckList[passwordfix] = [];
        }
        if (
          typeof g_allPasswords[passwordfix][domain2lvl] ==
          "undefined" ||
          (typeof g_allPasswords[passwordfix][domain2lvl] ==
            "function" &&
            typeof g_allPasswords[passwordfix][domain2lvl].push ==
            "undefined")
        ) {
          g_allPasswords[passwordfix][domain2lvl] = [];
          equvialentDomainCheckList[passwordfix][domain2lvl] = {users: [], hasDifferentUser: false};
        }

        try {
          g_allPasswords[passwordfix][domain2lvl].push(i);
          if (!equvialentDomainCheckList[passwordfix][domain2lvl]['hasDifferentUser'])
            equvialentDomainCheckList[passwordfix][domain2lvl]['users'].forEach(function (user) {
              if (user !== username) {
                equvialentDomainCheckList[passwordfix][domain2lvl]['hasDifferentUser'] = true;
                return;
              }
            })
          equvialentDomainCheckList[passwordfix][domain2lvl]['users'].push(username);
        } catch (e) {
          // Clean memory
          username =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          password =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          passwordfix =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          return;
        }
      }


      if (sfname != "nonshared") {
        if (
          typeof SharedPasswords[sfname][passwordfix] ==
          "undefined"
        )
          SharedPasswords[sfname][passwordfix] = [];
        if (
          typeof SharedPasswords[sfname][passwordfix][
            domain2lvl
            ] == "undefined" ||
          (typeof SharedPasswords[sfname][passwordfix][
              domain2lvl
              ] == "function" &&
            typeof SharedPasswords[sfname][passwordfix][
              domain2lvl
              ].push == "undefined")
        )
          SharedPasswords[sfname][passwordfix][domain2lvl] = [];
        try {
          SharedPasswords[sfname][passwordfix][domain2lvl].push(
            i
          );
        } catch (e) {
          // Clean memory
          username =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          password =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          passwordfix =
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
          return;
        }
      }

      if (++numsites > g_MAXNUMCOMPUTESCORE) {
        var setTimeout_function = null;
        try {
          if (typeof setTimeout == "function")
            setTimeout_function = setTimeout;
          else if (
            typeof LP != "undefined" &&
            typeof LP.mostRecent != "undefined" &&
            typeof LP.mostRecent().setTimeout != "undefined"
          )
            setTimeout_function = LP.mostRecent().setTimeout;
        } catch (e) {}

        var delay = 0;
        setTimeout_function(function () {

          challengecomputescore_async(
            i + 1,
            g_totalscore,
            g_sites,
            g_aSites,
            g_numsites,
            g_numblanksites,
            g_avgpasswordlength,
            g_aPasswords,
            g_MAXNUMCOMPUTESCORE,
            g_numduppasswords,
            g_numdupsites,
            g_usernames,
            WEAKPASSWORDSCORE,
            g_strengthscore,
            g_countscore,
            g_numweak,
            sharedavgstrength,
            SharedAccounts,
            g_runtimems,
            sfcounts,
            sharedstrengthscore,
            sharedblanksites,
            sharedweak,
            sharedavgpasswordlength,
            SharedPasswords,
            sharedcountscore,
            NonSharedAccounts,
            g_SFNames,
            AllSFNames,
            sharedtotalscore,
            g_numvulnerablesites,
            g_allPasswords,
            g_reuse,
            g_blanksites,
            g_allnumduppasswords,
            equvialentDomainCheckList,
            isExcludeSwitchedOn,
            excludedPasswords,
            domainsForAutomaticPasswordExclude,
            isFeatureEnabledSecurityDashboard2_0,
            dwmAlerts,
            SFNameToID,
            AIDtoSFNames,
            AllSFIDs,
            g_myaccounts,
            g_avgstrength
          );
        }, delay);

        // Clean memory
        username =
          "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        password =
          "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        passwordfix =
          "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        return;
      }

      // Clean memory
      username =
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
      password =
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
      passwordfix =
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    }
    g_challengeregexcache = [];
    g_avgpasswordlength =
      g_numsites == g_numblanksites
        ? 0
        : Math.round(
        (10 * g_avgpasswordlength) /
        (g_numsites - g_numblanksites)
      ) / 10;

    // Look for duplicates - root accounts
    var k;
    var aDomains;
    var aSites;
    var numdupsites;
    var numdomains;
    var pass;
    for (pass in g_aPasswords) {
      numdomains = 0;
      if (!g_aPasswords.hasOwnProperty(pass)) continue;
      aDomains = g_aPasswords[pass];
      var hasDuplicatedPassword = false;
      for (var domain in aDomains) {
        if (equvialentDomainCheckList[pass][domain].hasDifferentUser) {
          hasDuplicatedPassword = true;
        }
        if (!aDomains.hasOwnProperty(domain)) continue;
        numdomains++;
      }
      if ((numdomains == 1 && !hasDuplicatedPassword) || pass == "") {
        if (typeof g_reuse !== "undefined") {
          for (var jj in g_aPasswords[pass]) {
            for (var ii in g_aPasswords[pass][jj]) {
              delete g_reuse[g_aPasswords[pass][jj][ii]];
            }
          }
        }
        delete g_aPasswords[pass];
        continue;
      }
      ++g_numduppasswords;

      // At least 2 domains contain at least 1 site that has the same password ==> mark all of them as insecure!
      // EG: acme.com has 1 site whose password is "abc123"
      //     wolf.com has 3 sites whose password is "abc123"
      numdupsites = 0;
      for (var domain in aDomains) {
        if (!aDomains.hasOwnProperty(domain)) continue;
        numdupsites += g_aPasswords[pass][domain].length;
      }
      g_numdupsites += numdupsites;
      for (var domain in aDomains) {
        if (!aDomains.hasOwnProperty(domain)) continue;
        aSites = g_aPasswords[pass][domain];
        for (k in aSites) {
          if (!aSites.hasOwnProperty(k)) continue;
          i = g_aPasswords[pass][domain][k];
          g_aSites[i]["challenge_numduplicates"] = numdupsites;
          g_aSites[i]["challenge_duplicatescore"] =
            g_aSites[i]["challenge_score"] / numdomains;
        }
      }
    }
    // Clean memory
    pass =
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

    function calculateGlobalReusedPasses(){
      // Look for duplicates - Globally

      var k;
      var aDomains;
      var numdomains;
      var pass;
      // Clean memory
      pass =
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

      // If ALL passwords are 'password' or blank, g_allPasswords will not be defined
      if (typeof g_allPasswords == "undefined") {
        g_allPasswords = {};
      }

      for (pass in g_allPasswords) {
        if (!g_allPasswords.hasOwnProperty(pass)) continue;
        aDomains = g_allPasswords[pass];
        numdomains = 0;
        var hasDuplicatedPassword = false;
        for (var domain in aDomains) {
          if (equvialentDomainCheckList[pass][domain].hasDifferentUser) {
            hasDuplicatedPassword = true;
          }
          if (!aDomains.hasOwnProperty(domain)) continue;
          ++numdomains;
        }

        if ((numdomains == 1 && !hasDuplicatedPassword) || pass == "") {
          delete g_allPasswords[pass];
          continue;
        }
      }
    }

    calculateGlobalReusedPasses();

    function isPasswordBreached(passwordId) {
      var sitesObject = JSON.parse(g_sites);
      var credentialMonitoringBreachPresent = sitesObject[passwordId] && sitesObject[passwordId].last_credential_monitoring_state === '1';
      var credentialMonitoringBreachIgnoredOrDimissed = sitesObject[passwordId] && Number(sitesObject[passwordId].last_credential_monitoring_state) > 1;
      var relatedAlerts = dwmAlerts.filter(function(alert){
        return (
          lp_sha2lib.sha256(sitesObject[passwordId].unencryptedUsername) === alert.usernameHash &&
          sitesObject[passwordId].url.indexOf(alert.url) > -1
        )
      })
      return credentialMonitoringBreachPresent || (relatedAlerts.length && !credentialMonitoringBreachIgnoredOrDimissed);
    }

    // Clean memory
    pass =
      "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

    // Look for passwords that are not duplicates but are similar
    // TODO: SEE http://phpjs.org/functions/levenshtein:463

    // Compute total score and g_numweak and final scores
    var excludedPasswordCount = 0;
    for (i = 0; i < g_aSites.length; ++i) {
      if (typeof g_aSites[i]["sfname"] != "undefined")
        sfname = g_aSites[i]["sfname"];
      if (typeof g_aSites[i]["sfname"] == "undefined")
        sfname = "nonshared";
      if (typeof sharedweak[sfname] == "undefined")
        sharedweak[sfname] = 0;
      g_aSites[i]["challenge_scorefinal"] =
        g_aSites[i]["challenge_score"];

      // Capture usernames (only email addresses needed)
      if (
        g_aSites[i].usernamedec &&
        -1 !== g_aSites[i].usernamedec.indexOf("@") &&
        !(g_aSites[i].usernamedec in g_usernames)
      ) {
        g_usernames[g_aSites[i].usernamedec] = [];
        g_usernames[g_aSites[i].usernamedec].hash =
          lp_sha2lib.sha256(g_aSites[i].usernamedec);
        g_usernames[g_aSites[i].usernamedec].link =
          g_aSites[i].link;
      }

      if (
        typeof g_aSites[i]["challenge_dictionary"] != "undefined" &&
        typeof g_aSites[i]["challenge_duplicatescore"] !=
        "undefined"
      ) {
        g_aSites[i]["challenge_scorefinal"] =
          0.5 * g_aSites[i]["challenge_duplicatescore"]; // Dictionary AND Duplicate
        if (sfname == "nonshared") ++g_numweak;
        if (sfname != "nonshared") ++sharedweak[sfname];
        continue;
      }
      if (typeof g_aSites[i]["challenge_dictionary"] != "undefined") {
        g_aSites[i]["challenge_scorefinal"] =
          0.5 * g_aSites[i]["challenge_scorefinal"]; // Dictionary
        if (sfname == "nonshared") ++g_numweak;
        if (sfname != "nonshared") ++sharedweak[sfname];
        continue;
      }
      if (
        typeof g_aSites[i]["challenge_duplicatescore"] !=
        "undefined"
      ) {
        g_aSites[i]["challenge_scorefinal"] =
          g_aSites[i]["challenge_duplicatescore"]; // Duplicate
        if (typeof g_aSites[i]["sfname"] == "undefined") {
          g_strengthscore += (isFeatureEnabledSecurityDashboard2_0 && isPasswordBreached(g_aSites[i].id)) ? 0 : g_aSites[i]["challenge_duplicatescore"];
        }
        if (typeof g_aSites[i]["sfname"] != "undefined")
          sharedstrengthscore[sfname] +=
            g_aSites[i]["challenge_duplicatescore"];
        continue;
      }
      if (
        g_aSites[i]["challenge_score"] < WEAKPASSWORDSCORE &&
        g_aSites[i]["passworddecfix"] != ""
      ) {
        if (sfname == "nonshared") ++g_numweak;
        if (sfname != "nonshared") ++sharedweak[sfname];
      }
      if (sfname == "nonshared") {
        if (g_aSites[i]["is_excluded"] && g_aSites[i]["is_excluded"] === true && g_aSites[i]["passworddec"] !== '') {
          excludedPasswordCount++;
        } else {
          g_strengthscore += (isFeatureEnabledSecurityDashboard2_0 && isPasswordBreached(g_aSites[i].id)) ? 0 : g_aSites[i]["challenge_score"];
        }

        g_avgstrength =
          g_numsites == g_numblanksites
            ? 0
            : Math.round(
            (10 * g_strengthscore) /
            (g_numsites - g_numblanksites - excludedPasswordCount)
          ) / 10;
        if (NonSharedAccounts.length != 0) {
          g_avgstrength =
            NonSharedAccounts.length == g_numblanksites
              ? 0
              : Math.round(
              (10 * g_strengthscore) /
              (NonSharedAccounts.length -
                g_numblanksites - excludedPasswordCount)
            ) / 10;
        }
      }
      if (sfname != "nonshared") {
        sharedstrengthscore[sfname] +=
          g_aSites[i]["challenge_score"];
        sharedavgstrength[sfname] =
          sfcounts[sfname] == sharedblanksites[sfname]
            ? 0
            : Math.round(
            (10 * sharedstrengthscore[sfname]) /
            (SharedAccounts[sfname].length -
              sharedblanksites[sfname])
          ) / 10;
      }

      // Assign 2 points for every secure password you have saved up to 100

      if (typeof sharedcountscore[sfname] == "undefined")
        sharedcountscore[sfname] = 0;

      if (
        g_aSites[i]["challenge_score"] >= 70 &&
        typeof g_aSites[i]["sfname"] == "undefined"
      )
        g_countscore += 2;
      if (
        g_aSites[i]["challenge_score"] >= 70 &&
        typeof g_aSites[i]["sfname"] != "undefined"
      ) {
        sharedcountscore[sfname] += 2;
      }
    }
    if (g_countscore > 100) g_countscore = 100;
    if (sharedcountscore[sfname] > 100) sharedcountscore[sfname] = 100;

    // Done! Compute average score using a 90:10 weighting
    if (
      typeof NonSharedAccounts != "undefined" &&
      NonSharedAccounts.length != 0
    )
      g_numsites = NonSharedAccounts.length;
    var maximumScoreFromPasswords;
    if (g_numsites - g_numblanksites > 0) {
      if (isFeatureEnabledSecurityDashboard2_0) {
        maximumScoreFromPasswords = 70;
        var passwordStrengthWeight = 7;
        g_totalscore = Math.round(passwordStrengthWeight * (g_strengthscore / (g_numsites - g_numblanksites - excludedPasswordCount))) / 10;
        if (g_totalscore > maximumScoreFromPasswords){
          g_totalscore = maximumScoreFromPasswords;
        }
      } else {
        maximumScoreFromPasswords = 100;
        g_totalscore =
          Math.round(
            10 *
            (0.8 *
              (g_strengthscore /
                (g_numsites - g_numblanksites - excludedPasswordCount)) +
              g_countscore / 10)
          ) / 10;
        if (g_totalscore > maximumScoreFromPasswords) {
          g_totalscore = maximumScoreFromPasswords;
        }
      }
    }

    for (var i = 0; i < AllSFNames.length; i++) {
      sfname = AllSFNames[i];
      if (typeof SharedAccounts[sfname] == "undefined")
        SharedAccounts[sfname] = [];
      if (typeof sharedblanksites[sfname] == "undefined")
        sharedblanksites[sfname] = 0;
      if (
        SharedAccounts[sfname].length - sharedblanksites[sfname] >
        0
      ) {
        sharedtotalscore[sfname] =
          Math.round(
            10 *
            (0.8 *
              (sharedstrengthscore[sfname] /
                (SharedAccounts[sfname].length -
                  sharedblanksites[sfname])) +
              sharedcountscore[sfname] / 10)
          ) / 10;
      }
    }

    g_runtimems = new Date().getTime() - g_runtimems;
    var runtimesec = Math.round(g_runtimems / 1000);

    //OK, done. Report results.
    sendPostMessage();
  }

} else {
  //Zxcvbn-Worker initial phase done"
}

