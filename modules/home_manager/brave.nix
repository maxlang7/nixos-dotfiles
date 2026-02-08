{pkgs-unstable, ...}: 
{
  programs.chromium = {
      enable = true;
      package = pkgs-unstable.brave;
      extensions = [
        { id = "nffaoalbilbmmfgbnbgppjihopabppdk"; } # speed
        { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # sponsorblock 
        { id = "cjobgkekcenldbaenikebmbhffhhffef"; } # tetrys
        { id = "bnomihfieiccainjcjblhegjgglakjdd"; } # improvedtube
        { id = "dbcfpoaehlbfdeeaonihhkoocmjgalco"; } # better player
        { id = "cndibmoanboadcifjkjbdpjgfedanolh"; } # better canvas
        { id = "ghbmnnjooekpmoecnnnilnnbdlolhkhi"; } # google docs offline
      ];
      commandLineArgs = [
        "--disable-features=AutofillSavePaymentMethods"
      ];
    };
}