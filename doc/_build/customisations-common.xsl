<?xml version='1.0'?>
<!--
See:

 - parameters: http://docbook.sourceforge.net/release/xsl/current/doc/html/
 - http://www.sagehill.net/docbookxsl/ParametersInFile.html
 - http://www.sagehill.net/docbookxsl/CustomMethods.html#CustomizationLayer

Note: If you're passing a string parameter ("stringparam"), you need
what feels like extra quotes.
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:docbook="http://docbook.org/ns/docbook"
    version="1.0">

  <xsl:param name="admon.graphics" select="1"/>
  <xsl:param name="section.autolabel" select="1"/>
  <xsl:param name="section.label.includes.component.label" select="1"/>
  <xsl:param name="xref.with.number.and.title" select="1" />
  <xsl:param name="toc.section.depth" select="3" />
  <xsl:param name="html.stylesheet" select="'style.css overrides.css highlightjs/mono-blue.css'"/>
  <xsl:param name="html.script" select="'./highlightjs/highlight.pack.js ./highlightjs/loader.js'"/>
  <xsl:param name="admon.style" select="''" />
  <xsl:param name="callout.graphics.extension" select="'.svg'" />

  <xsl:template match="docbook:programlisting[@role='context']">
    <!--
        Delete "context" programlistings, which provide execution
        context to the doc-test tests.
    -->
  </xsl:template>
</xsl:stylesheet>
