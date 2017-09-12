Packer Arch
===========

Fork of [elasticdog/packer-arch](https://github.com/elasticdog/packer-arch),
only for qemu, to generate a cleaner image without any vagrant user.

Packer Arch is a bare bones [Packer](https://www.packer.io/) template and
installation script that can be used to generate a [Vagrant](https://www.vagrantup.com/)
base box for [Arch Linux](https://www.archlinux.org/).

Overview
--------

My goal was to roughly duplicate the attributes from a
[DigitalOcean](https://www.digitalocean.com/) Arch Linux droplet:

* 64-bit
* 4 GB disk
* 512 MB memory
* Only a single /root partition (ext4)
* No swap
* Includes the `base` and `base-devel` package groups
* OpenSSH is also installed and enabled on boot

The installation script follows the
[official installation guide](https://wiki.archlinux.org/index.php/Installation_Guide)
pretty closely, with a few tweaks to ensure functionality within a VM. Beyond
that, the only customizations to the machine are related to the vagrant user
and the steps recommended for any base box.

Usage
-----

Assuming that you already have Packer, you should be good to clone
this repo and go:

    $ git clone https://github.com/elasticdog/packer-arch.git
    $ cd packer-arch/
    $ packer build arch-template.json

It is possible to tweak the defined variables (see arch-template.json for more
details):

    $ packer build -vars ip4="192.168.0.10/24" arch-template.json

By default, the template enable DHCP and IPv6 autoconf, but a static IPv4 or
IPv6 can also be specified through the variables `ip4` and `ip6`.

License
-------

Packer Arch is provided under the terms of the
[ISC License](https://en.wikipedia.org/wiki/ISC_license).

Copyright &copy; 2013&#8211;2017, [Aaron Bull Schaefer](mailto:aaron@elasticdog.com).
