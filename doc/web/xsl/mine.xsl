<?xml version='1.0'?>

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.w3.org/1999/xhtml">

<xsl:import href="website-common.xsl"/>
<xsl:include href="mytoc.xsl"/>
<xsl:include href="myxref.xsl"/>
<xsl:include href="rss.xsl"/>

<xsl:output indent="yes"
            method="xml"
            encoding="UTF-8"
            doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
            doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd" />

<!-- keep the docbook stylesheets from adding target="_top" to all links -->
<xsl:param name="ulink.target" select="''" />

<xsl:param name="autolayout" select="document($autolayout-file, /*)" />

<!-- ==================================================================== -->

<xsl:template match="/">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="webpage">

  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <xsl:variable name="relpath">
    <xsl:call-template name="root-rel-path">
      <xsl:with-param name="webpage" select="."/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="filename">
    <xsl:apply-templates select="." mode="filename"/>
  </xsl:variable>

  <xsl:variable name="tocentry" select="$autolayout/autolayout//*[$id=id]"/>
  <xsl:variable name="toc" select="($tocentry/ancestor-or-self::toc
                                   |$autolayout/autolayout/toc[1])[last()]"/>

  <html lang="{@lang}" xml:lang="{@lang}">

    <xsl:apply-templates select="head" mode="head.mode"/>
    <xsl:apply-templates select="config" mode="head.mode"/>

    <body>

      <xsl:call-template name="allpages.banner"/>

      <div class="{name(.)}">
        <a name="{$id}"/>

        <table class="layout">
          <xsl:if test="$nav.table.summary!=''">
            <xsl:attribute name="summary">
              <xsl:value-of select="$nav.table.summary"/>
            </xsl:attribute>
          </xsl:if>
          <tr>
            <td class="menu">
              <xsl:choose>
                <xsl:when test="$toc">
                  <xsl:apply-templates select="$toc">
                    <xsl:with-param name="pageid" select="@id"/>
                  </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>&#160;</xsl:otherwise>
              </xsl:choose>
            </td>

            <xsl:call-template name="hspacer"/>

            <td class="main">
              <xsl:apply-templates select="./head/title" mode="title.mode"/>
              <xsl:apply-templates select="child::*[name(.) != 'webpage']"/>
              <xsl:call-template name="process.footnotes"/>
              <br/>
            </td>
          </tr>
        </table>

      </div>

      <xsl:call-template name="webpage.linkbar"/>
      <xsl:call-template name="webpage.footer"/>

      <xsl:call-template name="webpage.validator"/>

    </body>

  </html>
</xsl:template>

<xsl:template name="allpages.banner">

  <xsl:variable name="relpath">
    <xsl:call-template name="root-rel-path">
      <xsl:with-param name="webpage" select="."/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="banner-left"
                select="$autolayout/autolayout/config[@param='banner-left'][1]"/>
  <xsl:variable name="banner-right"
                select="$autolayout/autolayout/config[@param='banner-right'][1]"/>

  <div class="titlebar">
    <a>
      <xsl:attribute name="href">
        <xsl:value-of select="$relpath"/>
        <xsl:value-of select="($autolayout/autolayout/toc[@id='home'])[1]/@filename"/>
      </xsl:attribute>
      <xsl:if test="$banner-left">
        <img class="titlebarleft">
          <xsl:attribute name="src">
            <xsl:value-of select="$relpath"/>
            <xsl:value-of select="$banner-left/@value"/>
          </xsl:attribute>
          <xsl:attribute name="alt">
            <xsl:value-of select="$banner-left/@altval"/>
          </xsl:attribute>
        </img>
       </xsl:if>
    </a>
    <xsl:if test="$banner-right">
      <img class="titlebarright">
        <xsl:attribute name="src">
          <xsl:value-of select="$relpath"/>
          <xsl:value-of select="$banner-right/@value"/>
        </xsl:attribute>
        <xsl:attribute name="alt">
          <xsl:value-of select="$banner-right/@altval"/>
        </xsl:attribute>
      </img>
    </xsl:if>
  </div>
</xsl:template>

<xsl:template match="title" mode="head.mode">
  <xsl:variable name="title"
                select="$autolayout/autolayout/config[@param='title'][1]"/>
  <title>
    <xsl:if test="$title">
      <xsl:value-of select="$title/@value"/>
      -
    </xsl:if>
    <xsl:value-of select="."/>
  </title>
</xsl:template>

<xsl:template name="hspacer">
  <!-- nop -->
</xsl:template>

<xsl:template name="webpage.linkbar">
  <div class="linkbar">
    <xsl:apply-templates select="$autolayout/autolayout/headlink" mode="webpage.linkbar" />
  </div>
</xsl:template>

<xsl:template name="webpage.footer">
  <div>
  <span class="footerleft">
    <xsl:choose>
      <xsl:when test="head/copyright">
        <xsl:apply-templates select="head/copyright" mode="footer.mode"/>
      </xsl:when>
      <xsl:otherwise>
         <xsl:apply-templates mode="footer.mode"
                              select="$autolayout/autolayout/copyright"/>
      </xsl:otherwise>
    </xsl:choose>
  </span>
  <span class="footerright">
    <xsl:apply-templates select="$autolayout/autolayout/headlink" mode="webpage.footer" />
  </span>
  </div>
</xsl:template>

<xsl:template name="webpage.validator">
  <div style="clear: both; margin: 0; width: 100%; "></div>
  <div class="validator">
    <span style="position: absolute; left: 0; font-size: xx-small;">
      <a href="http://validator.w3.org/check/referer">Validate XHTML</a>
    </span>
  </div>
</xsl:template>

<xsl:template match="headlink" mode="webpage.linkbar">
  <xsl:if test="@rel='bookmark'">
    <a>
      <xsl:attribute name="href">
        <xsl:value-of select="@href" />
      </xsl:attribute>
      <xsl:value-of select="@title" />
    </a>
    <xsl:if test="following-sibling::headlink[@rel='bookmark']"> | </xsl:if>
  </xsl:if>
</xsl:template>

<xsl:template match="headlink" mode="webpage.footer">
  <xsl:if test="@rel='author'">
    <a>
      <xsl:attribute name="href">
        <xsl:value-of select="@href" />
      </xsl:attribute>
      <xsl:value-of select="@title" />
    </a>
  </xsl:if>
</xsl:template>

<xsl:template match="config[@param='filename']" mode="head.mode">
</xsl:template>

<xsl:template match="webtoc">
  <!-- nop -->
</xsl:template>

</xsl:stylesheet>
