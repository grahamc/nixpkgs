let
  pkgs = import ./.. { };
  lib = pkgs.lib;
  sources = lib.sourceFilesBySuffices ./. [".xml"];
  sources-langs = ./languages-frameworks;

  attrsOnly = attrset: lib.filterAttrs (k: v: builtins.isAttrs v) attrset;

  docbookFromDoc = { name, pos }: {
        # MUST match lib/doc.nix's mkDoc function signature
        description,
        examples ? [],
        type ? false
      }:
    let
      exampleDocbook = lib.strings.concatMapStrings ({title, body}: ''
        <example>
          <title>${title}</title>
          <programlisting><![CDATA[${body}]]></programlisting>
        </example>

      '') examples;

      typeDocbook = if type == false then ""
        else ''
        <para>${type}</para>
        '';

    in ''
      <section>
        <title>${name}</title>
        ${typeDocbook}
        <para>${pos.file}:${toString pos.line}</para>

        <para>${description}</para>

        ${exampleDocbook}
      </section>

    '';



  libSetDocFragments = libset: lib.mapAttrsToList
    (name: value:
      let
        pos = builtins.unsafeGetAttrPos name libset;
      in docbookFromDoc { inherit pos name; } value
    )
    (if builtins.hasAttr "docs" libset then libset.docs else {});

  libDocFragments = lib.mapAttrsToList
    (name: value:
      let
        docs = (lib.strings.concatStrings (libSetDocFragments value));
      in if builtins.stringLength docs == 0
      then ""
      else ''
        <section>
          <title>${name}</title>

          ${docs}
        </section>
      ''
    )
    (attrsOnly lib);

  libListDocs = pkgs.writeTextDir "lib-funcs.xml"
    ''
      <chapter xmlns="http://docbook.org/ns/docbook"
        xmlns:xlink="http://www.w3.org/1999/xlink"
        xml:id="chap-lib-functions">

        <title>Functions reference</title>

        ${lib.concatStringsSep "\n" libDocFragments}
      </chapter>
    '';

in
pkgs.stdenv.mkDerivation {
  name = "nixpkgs-manual";

  buildInputs = with pkgs; [ pandoc libxml2 libxslt zip ];

  xsltFlags = ''
    --param section.autolabel 1
    --param section.label.includes.component.label 1
    --param html.stylesheet 'style.css'
    --param xref.with.number.and.title 1
    --param toc.section.depth 3
    --param admon.style '''
    --param callout.graphics.extension '.gif'
  '';


  buildCommand = let toDocbook = { useChapters ? false, inputFile, outputFile }:
    let
      extraHeader = ''xmlns="http://docbook.org/ns/docbook" xmlns:xlink="http://www.w3.org/1999/xlink" '';
    in ''
      {
        pandoc '${inputFile}' -w docbook ${lib.optionalString useChapters "--top-level-division=chapter"} \
          --smart \
          | sed -e 's|<ulink url=|<link xlink:href=|' \
              -e 's|</ulink>|</link>|' \
              -e 's|<sect. id=|<section xml:id=|' \
              -e 's|</sect[0-9]>|</section>|' \
              -e '1s| id=| xml:id=|' \
              -e '1s|\(<[^ ]* \)|\1${extraHeader}|'
      } > '${outputFile}'
    '';
  in

  ''
    ln -s '${sources}/'*.xml .
    mkdir ./languages-frameworks
    cp -s '${libListDocs}'/* ./
    cp -s '${sources-langs}'/* ./languages-frameworks
  ''
  + toDocbook {
      inputFile = ./introduction.md;
      outputFile = "introduction.xml";
      useChapters = true;
    }
  + toDocbook {
      inputFile = ./languages-frameworks/python.md;
      outputFile = "./languages-frameworks/python.xml";
    }
  + toDocbook {
      inputFile = ./languages-frameworks/haskell.md;
      outputFile = "./languages-frameworks/haskell.xml";
    }
  + toDocbook {
      inputFile = ../pkgs/development/idris-modules/README.md;
      outputFile = "languages-frameworks/idris.xml";
    }
  + toDocbook {
      inputFile = ../pkgs/development/node-packages/README.md;
      outputFile = "languages-frameworks/node.xml";
    }
  + toDocbook {
      inputFile = ../pkgs/development/r-modules/README.md;
      outputFile = "languages-frameworks/r.xml";
    }
  + toDocbook {
      inputFile = ./languages-frameworks/rust.md;
      outputFile = "./languages-frameworks/rust.xml";
    }
  + toDocbook {
      inputFile = ./languages-frameworks/vim.md;
      outputFile = "./languages-frameworks/vim.xml";
    }
  + ''
    echo ${lib.nixpkgsVersion} > .version

    # validate against relaxng schema
    xmllint --nonet --xinclude --noxincludenode manual.xml --output manual-full.xml
    ${pkgs.jing}/bin/jing ${pkgs.docbook5}/xml/rng/docbook/docbook.rng manual-full.xml

    dst=$out/share/doc/nixpkgs
    mkdir -p $dst
    xsltproc $xsltFlags --nonet --xinclude \
      --output $dst/manual.html \
      ${pkgs.docbook5_xsl}/xml/xsl/docbook/xhtml/docbook.xsl \
      ./manual.xml

    cp ${./style.css} $dst/style.css

    mkdir -p $dst/images/callouts
    cp "${pkgs.docbook5_xsl}/xml/xsl/docbook/images/callouts/"*.gif $dst/images/callouts/

    mkdir -p $out/nix-support
    echo "doc manual $dst manual.html" >> $out/nix-support/hydra-build-products

    xsltproc $xsltFlags --nonet --xinclude \
      --output $dst/epub/ \
      ${pkgs.docbook5_xsl}/xml/xsl/docbook/epub/docbook.xsl \
      ./manual.xml

    cp -r $dst/images $dst/epub/OEBPS
    echo "application/epub+zip" > mimetype
    manual="$dst/nixpkgs-manual.epub"
    zip -0Xq "$manual" mimetype
    cd $dst/epub && zip -Xr9D "$manual" *
    rm -rf $dst/epub
  '';
}
