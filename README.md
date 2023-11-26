<p align="center">
<br/>
<a href="https://github.com/ursi">
  <img src="https://user-images.githubusercontent.com/26458780/278759718-c3b59702-6bb4-4fbf-8a1d-fff04e933dd2.png" height=250 title="NixThePlanet"/>
</a>
</p>

# NixThePlanet

This is a Nix flake that allows you to run medieval operating systems, some new
and some old. Some other candidate names for this flake were:

- `ProprietareKackscheisse`
- `nix-zoo`
- `Windows 12`
- `menagerie`

# Thanks

Massive thanks to the following for various help and with the repository!

- [Michael Hoang](https://github.com/enzime) For getting start with the idea
- [Robert Hensing](https://github.com/roberth) For putting up with determinism questions
- [Max Headroom](https://github.com/max-privatevoid) For figuring out why fetching was non deterministic when using `fetch-macOS-v2.py`
- [cleverca22](https://github.com/cleverca22/) For helping me sift through the QEMU source code

## macOS

Currently, only macOS Ventura is supported, building will take ***at least 40-50 minutes** as the official 11GiB macOS installer is downloaded and used in the Nix sandbox. **No user interaction is required**. Be patient and sit tight.

<img src="https://github.com/MatthewCroughan/NixThePlanet/assets/26458780/2720900d-637c-4cc3-9dbb-3be11da8c729">

#### Launch macOS Ventura with a single `nix` command

##### GTK

`nix run github:matthewcroughan/NixThePlanet#macos-ventura`

##### VNC (Port 5901)

You can pass QEMU flags like `-vnc`

`nix run github:matthewcroughan/NixThePlanet#macos-ventura -- -vnc 0.0.0.0:1`

#### Using the nixosModule

To enable the VM as a NixOS service via the `nixosModule` enable the macos-ventura module on a `nixosConfiguration` in your `flake.nix`

- SSH is accessible on port 2222 by default, but is configurable via `services.macos-ventura.sshPort`
- VNC is accessible on port 5900 by default, but is configurable via `services.macos-ventura.vncDisplayNumber`

```nix
{
  inputs = {
    nixtheplanet.url = "github:matthewcroughan/nixtheplanet";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
  };
  outputs = { self, nixpkgs, nixtheplanet }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      modules = [
        nixtheplanet.nixosModules.macos-ventura
        {
          services.macos-ventura = {
            enable = true;
            openFirewall = true;
            vncListenAddr = "0.0.0.0";
          };
        }
      ];
    };
  };
}
```

#### Using the `makeDarwinImage` function

This flake exports a function `makeDarwinImage` which takes a `diskSizeBytes` argument in order to influence the disk size of the resulting VM, it could be used like this in a `flake.nix` for example

```nix
{
  inputs = {
    nixtheplanet.url = "github:matthewcroughan/nixtheplanet";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
  };
  outputs = { self, nixpkgs, nixtheplanet }: {
    # Create a 60GB Darwin disk image, two ways of doing the same thing
    # x is accessing legacyPackages directly from the flake
    # y is applying the overlay from nixtheplanet unto its own instance of nixpkgs

    x = nixtheplanet.legacyPackages.x86_64-linux.makeDarwinImage { diskSizeBytes = 60000000000; };
    y = (import nixpkgs { system = "x86_64-linux"; overlays = [ nixtheplanet.overlays.default ]; }).makeDarwinImage { diskSizeBytes = 60000000000; };
  };
}
```

# TODO

- Remove dependency on vncdo, use qemu framebuffer directly
- Find a more reproducible way of fetching macOS BaseSystems, currently the
  board identifier determines what is fetched, and Apple changes what OS is
  compatible with which board identifier routinely
- Add amiga, macOS System 1 to 7, Windows 1.0, Windows 95 and Windows 98, and
  the rest.
- Find a way of getting serial access for Dosbox so we can make `runInWin311`
  and similar functions
- Implement `runInDarwinVM` using the `makeDarwinImage` primitive
- Remove dependency on OSX-KVM that is currently being cargo-culted into the
  repository without a git submodule
- Reproduce OpenCore qcow2 image ourselves
- Put screen captures into `$out` for the image builders using `vncdo`, would
  help with debugging
- Better logging in image builders
- Maybe make a framework for using `expect` and `tesseract` together with Nix,
  similar to the NixOS Testing Framework to reduce code duplication in this repo
- Make some installation options configurable, such as initial username/pass for
  all image builders
- Create a watchdog to retry if failure/hanging is encountered

# Known Issues

- On some CPUs macOS will fail to boot when using multiple cores due to macOS
  lacking drivers for host CPU timers, this has been encountered on an AMD Ryzen
  2700U for example,

- If the VM is too slow, Apple's macOS installer can hit race conditions and
  hang. A retry of the build of the derivation will usually fix this.

# Notes

Notable changes to the `OpenCore-Boot.sh` script for the OSX-KVM repository that
I am copy-pasting into this repo temporarily for bootstrapping purposes are:

- Using `snapshot=on` and generating QCOW2 images backed by raw disk images to
improve performance and disk usage during installation phase
- Using Virtio for all disks and gpu
- Disabling nic during installation
- Doing everything offline by default
- Limiting CPU to one core and thread for determinism, there were some threading
  issues during installation that caused non deterministic behavior and failed
  installations that lead to this.

I am also changing `scripts/run_offline.sh` to automatically partition the Disk,
and not embedding it into the InstallAssistant, to allow for reconfiguration of
the run_offline script in a separate derivation.
