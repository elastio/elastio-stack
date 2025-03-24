# Cleanup

If you'd like to clean up your environment from resources deployed by Elastio, then download and run the `aws-gc` binary developed by Elastio as shown below.

It discovers all resources with `elastio:resource` tag or with `elastio` in their name, shows the list of all of them, asks you to confirm by typing `yes`, and starts the deletion.

Run one of the following scripts in AWS Cloudshell or locally on your own machine. Choose the script depending on your OS.

## Linux

```bash
curl -fLS "https://dl.cloudsmith.io/public/elastio/public/raw/versions/latest/aws-gc_$(uname -m | sed "s/arm64/aarch64/")-unknown-linux-musl.tar.xz" | sudo tar -xJf - -C /usr/local/bin

aws-gc destroy --tag elastio:resource=true --id-pattern elastio
```

## Windows

```bash
Invoke-WebRequest "https://dl.cloudsmith.io/public/elastio/public/raw/versions/latest/aws-gc_x86_64-pc-windows-msvc.zip" -OutFile "aws-gc.zip";
Expand-Archive -Force "aws-gc.zip";
Move-Item -Force "./aws-gc/aws-gc.exe" "./aws-gc.exe";
Remove-Item -Force "./aws-gc", "./aws-gc.zip";

./aws-gc.exe destroy --tag elastio:resource=true --id-pattern elastio
```

## MacOS

```bash
curl -fLS "https://dl.cloudsmith.io/public/elastio/public/raw/versions/latest/aws-gc_$(uname -m | sed "s/arm64/aarch64/")-apple-darwin.tar.xz" | sudo tar -xJf - -C /usr/local/bin

aws-gc destroy --tag elastio:resource=true --id-pattern elastio
```

## Troubleshooting

### Premature Cloudshell Session Termination

If AWS Cloudshell is terminating before `aws-gc` completes, then try restarting it again. The cleanup script is idempotent, and if it's aborted in the middle the deletion progress won't be undone. You can also limit the regions where it discovers the resources with the `--regions` parameter to speed up `aws-gc` a bit.

As a fallback try running the cleanup from your local machine.
