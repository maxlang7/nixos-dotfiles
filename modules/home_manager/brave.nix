{config, pkgs, ...}: 
{
  programs.chromium = {
      enable = true;
      package = pkgs.brave;
      extensions = [
        { id = "nffaoalbilbmmfgbnbgppjihopabppdk"; } # speed
        { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # sponsorblock 
        { id = "cjobgkekcenldbaenikebmbhffhhffef"; } # tetrys
        { id = "bnomihfieiccainjcjblhegjgglakjdd"; } # improvedtube
        { id = "dbcfpoaehlbfdeeaonihhkoocmjgalco"; } # better player
        { id = "cndibmoanboadcifjkjbdpjgfedanolh"; } # better canvsa
        { id = "ghbmnnjooekpmoecnnnilnnbdlolhkhi"; } # google docs offline
      ];
      commandLineArgs = [
        "--disable-features=AutofillSavePaymentMethods"
      ];
    };
}