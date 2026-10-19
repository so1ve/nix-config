let
  ray = "age1akltajycaa4gwkpg3qetmlslp5cd9llx7q6mpr4rk4npfu9tzqfs9yd982";
in
{
  "github-ssh.age".publicKeys = [ ray ];
  "mihomo-config.age".publicKeys = [ ray ];
  "omp-models.age".publicKeys = [ ray ];
  "wireguard-private-key.age".publicKeys = [ ray ];
}
