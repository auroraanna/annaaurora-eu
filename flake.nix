{
  description = "Build Anna Aurora's website";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    Lyrically-Vantage.url = "https://codeberg.org/annaaurora/Lyrically-Vantage/archive/main.tar.gz";
    Lettuce-Synthetic.url = "https://codeberg.org/annaaurora/Lettuce-Synthetic/archive/main.tar.gz";
    Find-Billy = {
      url =
        "tarball+https://codeberg.org/attachments/5f0815d4-2ff6-4795-bd8c-2e3534e10c4c";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, Lyrically-Vantage, Lettuce-Synthetic, Find-Billy }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        packageName = "annaaurora.eu";
      in rec {
        packages.${packageName} = pkgs.stdenvNoCC.mkDerivation {
          name = packageName;
          src = self;

          nativeBuildInputs = with pkgs; [
            exiftool
            zola
            html-tidy
            imagemagick
            lmms
            ffmpeg
            xxHash
          ];

          buildPhase = ''
            runHook preBuild

            # Replace placeholder.
            substituteInPlace config.toml --replace '$annaaurora.eu_out' "$out"
            # Replace big icon with big enough icon even for 2160x3840 500 phone screen.
            magick static/icon.jpeg -resize 160x160 static/icon.webp
            # Lettuce Synthetic
            sh lettuce-synthetic.sh ${Lettuce-Synthetic.packages.${system}.default}
            # Let Zola compile the website and format HTML
            zola build
            for file in $(find public -name '*.html'); do
              tidy -m --wrap 0 --indent true --indent-with-tabs false --indent-spaces 4 $file && echo "Formatted $file"
              sed -i 's/    /	/g' $file
            done
            # Fix `atom.xml`
            sed -i 's/href="\//href="https:\/\/annaaurora.eu\//g' public/atom.xml
            # Fix `robots.txt`
            sed -i 's/Sitemap: \//Sitemap: https:\/\/{{NAME}}\//g' public/robots.txt
            # Copy license file into top directory
            cp content/License.md public/LICENSE.md
            # Put Lyrically Vantage FLAC file into place.
            cp -v ${Lyrically-Vantage.packages.${system}.default}/"Lyrically Vantage.flac" public/art/lyrically-vantage/lossless.flac
            cp -v ${Lyrically-Vantage.packages.${system}.default}/"Lyrically Vantage.mmpz" public/art/lyrically-vantage/source.mmpz
            # Art section lossy media
            sh lossy.sh
            # Add checksum to every image URL for caching
            sh checksums.sh
            # Delete error 404 page because the Caddy web server delivers the error 404 page from somewhere else.
            rm public/404.html
            # Update Find Billy!
            cp -vr ${Find-Billy}/"Find Billy for Web v0.37.2" public/find-billy

            runHook postBuild
          '';

          installPhase = ''
            mkdir -p $out
            cp -vrf public/. $out/
          '';

          meta = with lib; {
            description = "Anna Aurora's website";
            homepage = "https://annaaurora.eu";
            license = licenses.cc-by-sa-40;
            maintainers = with maintainers; [ annaaurora ];
            platforms = platforms.all;
          };
        };

        packages.default = self.packages.${system}.${packageName};

        devShells.${packageName} = pkgs.mkShell {
          nativeBuildInputs = self.packages.${system}.${packageName}.nativeBuildInputs;
        };

        devShells.default = self.devShells.${system}.${packageName};
      });
}
