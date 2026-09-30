{
  writeShellApplication,
  coreutils,
  curl,
  findutils,
  gawk,
  gnused,
  gnutar,
  gum,
  jq,
  yq-go,
}:

writeShellApplication {
  name = "omp-provider";
  runtimeInputs = [
    coreutils
    curl
    findutils
    gawk
    gnused
    gnutar
    gum
    jq
    yq-go
  ];
  text = builtins.readFile ./omp-provider.sh;
}
