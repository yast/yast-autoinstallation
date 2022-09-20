<xsl:stylesheet version="1.0"
  xmlns:n="http://www.suse.com/1.0/yast2ns"
  xmlns:config="http://www.suse.com/1.0/configns"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.suse.com/1.0/yast2ns" exclude-result-prefixes="n">

<!--
Convert the AutoYaST scheme with the old type specification to the new format.
It simply replaces all "config:type" attributes with simple "t" attribute.

NOTE: The new format is supported in SLES15-SP3 and newer, if you need to use
the profile in older systems you need to use the old "config:type" attributes!

See the old_types.xslt file for the opposite conversion.
-->

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@config:type">
    <xsl:attribute name="t">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
