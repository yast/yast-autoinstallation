<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:suwl="http://nwalsh.com/xslt/ext/com.nwalsh.saxon.UnwrapLinks"
                exclude-result-prefixes="suwl"
                version="1.0">

<!--  FIXME:                                                    -->
<!--  This stylesheet overrides the ulink template from         -->
<!--  the docbook xhtml stylesheets. The goal is to be able to  -->
<!--  specify a type attribute for the anchor. The dirty hack   -->
<!--  used here is to copy the template and introduce the       -->
<!--  invalid attribute "mimetype".                             -->

<xsl:template match="ulink" name="ulink">
  <xsl:variable name="link">
    <a xmlns="http://www.w3.org/1999/xhtml">
      <xsl:if test="@id">
        <xsl:attribute name="id">
          <xsl:value-of select="@id"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:attribute name="href">
        <xsl:value-of select="@url"/>
      </xsl:attribute>
      <xsl:if test="@mimetype">
        <xsl:attribute name="type">
          <xsl:value-of select="@mimetype"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="$ulink.target != ''">
        <xsl:attribute name="target">
          <xsl:value-of select="$ulink.target"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="count(child::node())=0">
          <xsl:value-of select="@url"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates/>
        </xsl:otherwise>
      </xsl:choose>
    </a>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="function-available('suwl:unwrapLinks')">
      <xsl:copy-of select="suwl:unwrapLinks($link)"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:copy-of select="$link"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
