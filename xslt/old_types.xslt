<xsl:stylesheet version="1.0"
  xmlns:n="http://www.suse.com/1.0/yast2ns"
  xmlns:config="http://www.suse.com/1.0/configns"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.suse.com/1.0/yast2ns" exclude-result-prefixes="n">

<!--
Convert the AutoYaST scheme with the new type specification to the old format.
It simply replaces all "t" attributes with "config:type" attribute.

NOTE: The new format is supported in SLES15-SP3 and newer, if you need to use
a profile in older systems this XSL file will make the profile work there.

See the new_types.xslt file for the opposite conversion.
-->

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@t">
    <xsl:attribute name="config:type">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
