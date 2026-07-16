# System-level Brave policy.
#
# Brave/Chromium on Linux only read enterprise policy from
# /etc/<browser>/policies/managed/, which home-manager cannot write — so the
# force-install list lives here, at system scope, rather than in the
# home-manager brave module (which owns the package + launch flags).
#
# This replaces the previously hand-written /etc/brave/policies/managed/policies.json.
{...}:
let
  updateUrl = "https://clients2.google.com/service/update2/crx";

  # Every extension is force-installed (locked: always present, cannot be
  # disabled/removed). Keep this list as the single source of truth.
  extensions = {
    "aapbdbdomjkkjkaonfhkkikfgjllcleb" = "Google Translate";
    "abaeffeoghdijpompgnhikjcgnkacdmb" = "YouTube Clipper";
    "alncdjedloppbablonallfbkeiknmkdi" = "Dark Mode - Night Eye";       # pinned
    "blaaajhemilngeeffpbfkdjjoefldkok" = "LeechBlock NG";
    "bnomihfieiccainjcjblhegjgglakjdd" = "Improve YouTube!";
    "cndibmoanboadcifjkjbdpjgfedanolh" = "BetterCampus (BetterCanvas)";
    "fbhbfbladmbgakfkccbfjpbabagjcmid" = "Delay";
    "fcoeoabgfenejglbffodgkkbkcdhcgfn" = "Claude";
    "ghbmnnjooekpmoecnnnilnnbdlolhkhi" = "Google Docs Offline";
    "ghnomdcacenbmilgjigehppbamfndblo" = "The Camelizer";
    "ihennfdbghdiflogeancnalflhgmanop" = "gruvbox theme";
    "mmioliijnhnoblpgimnlajmefafdfilb" = "Shazam";                      # pinned
    "mnjggcdmjocbbbhaepdhchncahnbgone" = "SponsorBlock";
    "nffaoalbilbmmfgbnbgppjihopabppdk" = "Video Speed Controller";
    "njgehaondchbmjmajphnhlojfnbfokng" = "Video Downloader PLUS";
    "nngceckbapebfimnlniiiahkandclblb" = "Bitwarden Password Manager";  # pinned
    "oocalimimngaihdkbihfgmpkcpnmlaoa" = "Netflix Party / Teleparty";
    "ppkjalpibdaiahjefbapemimobpkpond" = "Overleaf Dark Mode";
  };

  forcelist = map (id: "${id};${updateUrl}") (builtins.attrNames extensions);

  policies = {
    ExtensionInstallForcelist = forcelist;
  };
in
{
  environment.etc."brave/policies/managed/policies.json".text =
    builtins.toJSON policies;
}
