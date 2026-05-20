import java.io.*;
import java.net.*;
import java.util.*;
import java.util.regex.*;

public class readhtmltable {
    public static void main(String[] args) {
        if(args.length != 1) {
            System.out.println("Usage: java readhtmltable https://en.wikipedia.org/wiki/Comparison_of_programming_languages");
            return;
        }
        String input = args[0];
        String htmlContent = "";

        try {
            htmlContent = readInput(input);
            List<String> tables = extractTables(htmlContent);

            if(tables.size() == 0) {
                System.out.println("No tables found");
                return;
            }

            int tbleCount = 1;
            for (String table:tables) {
                List<List<String>> parsedTable = parseTable(table);
                writeCSV(parsedTable, "table_" + tbleCount + ".csv");
                System.out.println("Wrote table_" + tbleCount + ".csv");
                tbleCount++;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    public static String readInput(String urlString) throws IOException {
        URL url = new URL(urlString);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
    
        connection.setRequestProperty("User-Agent", 
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");

        BufferedReader reader = new BufferedReader (
            new InputStreamReader(connection.getInputStream()));

        StringBuilder sb = new StringBuilder();
        String line;
        while((line = reader.readLine()) != null) {
            sb.append(line).append("\n");
        }
        reader.close();
        return sb.toString();
} 
public static List<String> extractTables(String html) {
    List<String> tables = new ArrayList<>();

    Pattern tblePattern = Pattern.compile(
        "<table.*?>.*?</table>",
        Pattern.DOTALL | Pattern.CASE_INSENSITIVE);

    Matcher match = tblePattern.matcher(html);
    while (match.find()) {
        tables.add(match.group());
    }
    return tables;
}
public static List<List<String>> parseTable(String tbleHtml) {
    List<List<String>> table = new ArrayList<>();
    Pattern rowPattern = Pattern.compile(
        "<tr.*?>(.*?)</tr>",
        Pattern.DOTALL | Pattern.CASE_INSENSITIVE);

    Matcher rowMatch = rowPattern.matcher(tbleHtml);
    while (rowMatch.find()) {
        String rowHtml = rowMatch.group(1);
        List<String> row = new ArrayList<>();
        Pattern cellPattern = Pattern.compile(
            "<t[dh].*?>(.*?)</t[dh]>",
            Pattern.DOTALL | Pattern.CASE_INSENSITIVE);
        Matcher cellMatch = cellPattern.matcher(rowHtml);

        while (cellMatch.find()) {
            String cell = cellMatch.group(1);

            //remove any remaining html tags inside cell
            cell = cell.replaceAll("<.*?>","");
            //clean whitespace
            cell = cell.replaceAll("\\s+"," ").trim();
            row.add(cell);
        }
        if (!row.isEmpty()) {
            table.add(row);
        }
    }
    return table;
}
public static void writeCSV(List<List<String>> table, String filename) throws IOException {
    BufferedWriter writer = new BufferedWriter(
        new FileWriter(filename));

        for(List<String> row:table) {
            for(int i=0; i<row.size(); i++) {
                String cell = row.get(i);
                //escape quotes
                cell = cell.replace("\"", "\"\"");
                //wrap in quotes in case of commas
                writer.write("\"" + cell + "\"");
                if(i<row.size() - 1) {
                    writer.write(",");
                }
            }
            writer.newLine();
        }
    writer.close();
}
}