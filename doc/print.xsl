<?xml version='1.0'?> 
<xsl:stylesheet  
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" 
    xmlns:fo="http://www.w3.org/1999/XSL/Format" >

<xsl:import href="docbook-fo.xsl"/> 
<xsl:param name="fop.extensions">1</xsl:param>
<xsl:param name="section.autolabel">1</xsl:param>
<xsl:param name="section.autolabel">1</xsl:param>
<xsl:param name="appendix.autolabel">1</xsl:param>
<xsl:param name="my.corporate.logo">img/linux-4aicons-p.png</xsl:param>

<xsl:template match="title" mode="chapter.titlepage.recto.auto.mode">  
  <fo:block xsl:use-attribute-sets="chapter.titlepage.recto.style" 
            margin-left="{$title.margin.left}" 
            font-size="20pt" 
            font-weight="bold" 
            font-family="{$title.font.family}">
    <xsl:call-template name="component.title">
      <xsl:with-param name="node" select="ancestor-or-self::chapter[1]"/>
    </xsl:call-template>
    <xsl:call-template name="division.title">
      <xsl:with-param name="node" select="ancestor-or-self::book[1]"/>
    </xsl:call-template>
  </fo:block>
</xsl:template>



<!-- LOGO -->

<!--
<xsl:template match="corpauthor" mode="book.titlepage.recto.mode">
    <fo:external-graphic  width="8cm"  src="img/suselogo.png" break-after="1"/>
    <fo:inline color="blue">
        <xsl:apply-templates mode="titlepage.mode"/>
    </fo:inline>
</xsl:template>
-->






<xsl:attribute-set name="section.title.properties">
  <xsl:attribute name="font-family">
    <xsl:value-of select="$title.font.family"/>
  </xsl:attribute>
  <xsl:attribute name="font-weight">bold</xsl:attribute>
  <!-- font size is calculated dynamically by section.heading template -->
  <xsl:attribute name="keep-with-next.within-column">always</xsl:attribute>
  <xsl:attribute name="space-before.minimum">0.8em</xsl:attribute>
  <xsl:attribute name="space-before.optimum">1.0em</xsl:attribute>
  <xsl:attribute name="space-before.maximum">1.2em</xsl:attribute>
</xsl:attribute-set>


<xsl:attribute-set name="section.title.level1.properties">
  <xsl:attribute name="font-size">
    <xsl:value-of select="$body.font.master * 1.8"/>
    <xsl:text>pt</xsl:text>
  </xsl:attribute>
</xsl:attribute-set>

<xsl:attribute-set name="section.title.level2.properties">
  <xsl:attribute name="font-size">16pt</xsl:attribute>
</xsl:attribute-set>

<!--
<xsl:attribute-set name="section.level1.properties">
  <xsl:attribute name="break-before">page</xsl:attribute>
</xsl:attribute-set>
-->

<!-- Programlisting -->
<xsl:attribute-set name="monospace.verbatim.properties"
use-attribute-sets="verbatim.properties">
  <xsl:attribute name="font-family">
    <xsl:value-of select="$monospace.font.family"/>
  </xsl:attribute>
  <xsl:attribute name="font-size">
    <xsl:value-of select="$body.font.master * 0.7"/>
    <xsl:text>pt</xsl:text>
  </xsl:attribute>
<!--
  <xsl:attribute name="border-color">#0000FF</xsl:attribute>
  <xsl:attribute name="border-style">solid</xsl:attribute>
  <xsl:attribute name="border-width">heavy</xsl:attribute>
-->
  <xsl:attribute name="background-color">#F0F0F0</xsl:attribute>
</xsl:attribute-set>


<xsl:template match="processing-instruction('anas-pagebreak')">
    <fo:block xmlns:fo="http://www.w3.org/1999/XSL/Format" break-before='page'/>
</xsl:template>

<!-- sidebar -->
<!--
  <xsl:attribute-set name="sidebar.properties">
    <xsl:attribute name="width">2.5in</xsl:attribute>
    <xsl:attribute name="padding-left">1em</xsl:attribute>
    <xsl:attribute name="padding-right">1em</xsl:attribute>
    <xsl:attribute name="start-indent">2em</xsl:attribute>
  </xsl:attribute-set>

  <xsl:template match="sidebar">
    <fo:float float="outside">
      <fo:block xsl:use-attribute-sets="sidebar.properties">
        <xsl:if test="./title">
          <fo:block font-weight="bold"
            keep-with-next.within-column="always"
            hyphenate="false">
            <xsl:apply-templates select="./title"
mode="sidebar.title.mode"/>
          </fo:block>
        </xsl:if>
        
        <xsl:apply-templates/>
        <xsl:if test=".//footnote">
          <fo:block font-family="{$body.font.family}"
            font-size="{$footnote.font.size}"
            keep-with-previous="always">
            <xsl:apply-templates select=".//footnote"
mode="table.footnote.mode"/>
          </fo:block>
        </xsl:if>
      </fo:block>
    </fo:float>
  </xsl:template>

  <xsl:template match="sidebar//footnote">
    <xsl:call-template name="format.footnote.mark">
      <xsl:with-param name="mark">
        <xsl:apply-templates select="." mode="footnote.number"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  -->
<xsl:include href="xsl/mytitlepages.xsl"/>

</xsl:stylesheet>
