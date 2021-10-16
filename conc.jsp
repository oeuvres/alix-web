<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" trimDirectiveWhitespaces="true"%>
<%@ page import="java.util.Arrays" %>
<%@ page import="org.apache.lucene.util.automaton.Automaton" %>
<%@ page import="org.apache.lucene.util.automaton.ByteRunAutomaton" %>
<%@ page import="alix.lucene.util.WordsAutomatonBuilder" %>
<%@ include file="jsp/prelude.jsp" %>
<%!
public void kwic(final PageContext page, final Alix alix, final TopDocs topDocs, Pars pars) throws IOException, NoSuchFieldException
{
  JspWriter out = page.getOut();
  if (topDocs == null) return;
  
  boolean repetitions = false;
  ByteRunAutomaton include = null;
  if (pars.forms != null) {
    Automaton automaton = WordsAutomatonBuilder.buildFronStrings(pars.forms);
    if (automaton != null) include = new ByteRunAutomaton(automaton);
    if (pars.forms.length == 1) repetitions = true;
  }
  // get the index in results
  ScoreDoc[] scoreDocs = topDocs.scoreDocs;

  
  // where to start loop ?
  int i = pars.start - 1; // private index in results start at 0
  int max = scoreDocs.length;
  if (i < 0) i = 0;
  else if (i > max) i = 0;
  // loop on docs
  int docs = 0;
  final int gap = 5;
  

  // be careful, if one term, no expression possible, this will loop till the end of corpus
  boolean expression = false;
  if (pars.forms == null) expression = false;
  else expression = pars.expression;
  int occ = 0;
  while (i < max) {
    final int docId = scoreDocs[i].doc;
    i++; // loop now
    final Doc doc = new Doc(alix, docId);
    String type = doc.doc().get(Alix.TYPE);
    // TODO Enenum
    if (type.equals(DocType.book.name())) continue;
    // if (doc.doc().get(pars.fieldName) == null) continue; // not a good test, field may be indexed but not store
    String href = pars.href + "&amp;q=" + JspTools.escUrl(pars.q) + "&amp;id=" + doc.id() + "&amp;start=" + i + "&amp;sort=" + pars.sort.name();
    
    // show simple metadata
    out.println("<!-- docId=" + docId + " -->");
    if (pars.forms == null || pars.forms.length == 0) {
      out.println("<article class=\"kwic\">");
      out.println("<header>");
      out.println("<small>"+(i)+".</small> ");
      out.print("<a href=\"" + href + "\">");
      String year = doc.get("year");
      if (year != null) {
        out.print(doc.get("year"));
        out.print(", ");
      }
      out.print(doc.get("title"));
      out.print(". ");
      out.print(doc.get("analytic"));
      out.print("</a>");
      out.println("</header>");
      out.println("</article>");
      if (++docs >= pars.hpp) break;
      continue;
    }
    
    String[] lines = null;
    lines = doc.kwic(pars.fieldName, include, href.toString(), 200, pars.left, pars.right, gap, expression, repetitions);
    if (lines == null || lines.length < 1) continue;
    // doc.kwic(field, include, 50, 50, 100);
    out.println("<article class=\"kwic\">");
    out.println("<header>");
    out.println("<b>"+(i)+"</b> ");

    out.print("<a href=\""+href+"\">");
    String year = doc.get("year");
    if (year != null) {
      out.print(doc.get("year"));
      out.print(", ");
    }
    out.print(doc.get("title"));
    out.print(". ");
    out.print(doc.get("analytic"));
    out.println("</a></header>");
    for (String l: lines) {
      out.println("<div class=\"line\"><small>"+ ++occ +"</small>"+l+"</div>");
    }
    out.println("</article>");
    if (++docs >= pars.hpp) break;
  }

}


%>
<%
Pars pars = pars(pageContext);
pars.forms = alix.forms(pars.q);
// local param
pars.left = 50;
pars.right = 70;


// build query and get results
long nanos = System.nanoTime();
Query query = null;
Query qWords = null;
Query qFilter = null;
if (pars.q != null) {
  qWords = alix.query(pars.fieldName, pars.q);
}
if (pars.book != null) {
  qFilter = new TermQuery(new Term(Alix.BOOKID, pars.book));
}
if (qWords != null && qFilter != null) {
  query = new BooleanQuery.Builder()
    .add(qFilter, Occur.FILTER)
    .add(qWords, Occur.MUST)
    .build();
}
else if (qWords != null) query = qWords;
else if (qFilter != null) query = qFilter;
else query = QUERY_CHAPTER;

TopDocs topDocs = null;
IndexSearcher searcher = alix.searcher();
int totalHitsThreshold = Integer.MAX_VALUE;
final int numHits = alix.reader().maxDoc();
TopDocsCollector<?> collector = null;

if (pars.sort != null && pars.sort.sort() != null) {
  collector = TopFieldCollector.create(pars.sort.sort(), numHits, totalHitsThreshold);
}
else {
  collector = TopScoreDocCollector.create(numHits, totalHitsThreshold);
}


searcher.search(query, collector);
topDocs = collector.topDocs();

out.println("<!-- get topDocs "+(System.nanoTime() - nanos) / 1000000.0 + "ms\" -->");

%>
<!DOCTYPE html>
<html>
  <head>
   <jsp:include page="local/head.jsp" flush="true" />
   <title>Concordance, <%= alix.props.get("label")%> [Alix]</title>
   <style>
span.left {display: inline-block; text-align: right; width: <%= Math.round(pars.left * 1.0)%>ex; padding-right: 1ex;}
    </style>
  </head>
  <body>
    <header>
      <jsp:include page="local/tabs.jsp" flush="true" />
      <form  class="search">
        <input type="hidden" name="f" value="<%= JspTools.escape(pars.fieldName) %>"/>
        <label for="q">Chercher</label>
        <button style="position: absolute; left: -9999px" type="submit">▶</button>
        <input name="q" id="q" value="<%=JspTools.escape(pars.q)%>" autocomplete="off" size="60" autofocus="autofocus" 
          onfocus="this.setSelectionRange(this.value.length,this.value.length);"
          oninput="this.form['start'].value='';"
        />
        <label>Expressions <input type="checkbox" name="expression" value="true" <%= (pars.expression)?"checked=\"checked\"":"" %>/></label>
        <br/><label for="book" title="Limiter la sélection à un seul livre">Livre</label>
        <%= selectBook(alix, pars.book) %>
        <select name="sort" onchange="this.form['start'].value=''; this.form.submit()" title="Ordre">
          <option/>
          <%= pars.sort.options() %>
        </select>
        <% // prev / next nav
        if (pars.start > 1 && pars.q != null) {
          int n = Math.max(1, pars.start - pars.hpp);
          out.println("<button name=\"next\" type=\"submit\" onclick=\"this.form['start'].value="+n+"\">◀</button>");
        }
        if (topDocs != null) {
          long max = topDocs.totalHits.value;
          out.println("<input  name=\"start\" value=\""+ pars.start+"\" autocomplete=\"off\" class=\"start num3\"/>");
          out.println("<span class=\"hits\"> / "+ max  + "</span>");
          int n = pars.start + pars.hpp;
          if (n < max) out.println("<button name=\"next\" type=\"submit\" onclick=\"this.form['start'].value="+n+"\">▶</button>");
        }
        /*
        if (forms == null || forms.length < 2 );
        else if (expression) {
          out.println("<button title=\"Cliquer pour dégrouper les locutions\" type=\"submit\" name=\"expression\" value=\"false\">✔ Locutions</button>");
        }
        else {
          out.println("<button title=\"Cliquer pour grouper les locutions\" type=\"submit\" name=\"expression\" value=\"true\">☐ Locutions</button>");
        }
        */
  
        %>
        
       </form> 
    </header>
    <main>
       <!-- query=<%= query %> totalHits=<%= topDocs.totalHits %> forms=<%= Arrays.toString(pars.forms) %> -->
       <% 
       pars.href = "doc.jsp?";
       kwic(pageContext, alix, topDocs, pars); 
       %>

    <% 
    /*
if (start > 1 && q != null) {
  int n = Math.max(1, start-hppDefault);
  out.println("<button name=\"prev\" type=\"submit\" onclick=\"this.form['start'].value="+n+"\">◀</button>");
}
    
    //  <input type="hidden" id="q" name="q" 
if (topDocs != null) {
  long max = topDocs.totalHits.value;
  out.println("<input  name=\"start\" value=\""+start+"\" autocomplete=\"off\" class=\"start\"/>");
  out.println("<span class=\"hits\"> / "+ max  + "</span>");
  int n = start + hpp;
  if (n < max) out.println("<button name=\"next\" type=\"submit\" onclick=\"this.form['start'].value="+n+"\">▶</button>");
}
    */
        %>
      <p> </p>
    </main>
  </body>
  <!-- <%= ((System.nanoTime() - time) / 1000000.0) %> ms  -->
</html>
