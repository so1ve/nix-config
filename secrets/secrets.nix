let
  ray = "age1akltajycaa4gwkpg3qetmlslp5cd9llx7q6mpr4rk4npfu9tzqfs9yd982";
in
{
  "deepseek-api-key.age".publicKeys = [ ray ];
  "github-ssh.age".publicKeys = [ ray ];
  "mihomo-config.age".publicKeys = [ ray ];
}
