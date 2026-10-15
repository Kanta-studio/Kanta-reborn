package ph.kanta.reborn;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;
import java.io.IOException;
import java.util.*;
import java.util.function.BooleanSupplier;

/** Traverses only provider children of the explicitly selected SAF tree. */
final class DocumentTreeScanner {
  private static final class Directory {
    final String id;
    final int depth;

    Directory(String id, int depth) {
      this.id = id;
      this.depth = depth;
    }
  }

  static List<Uri> scan(ContentResolver resolver, Uri tree, BooleanSupplier cancelled)
      throws Exception {
    ArrayDeque<Directory> directories = new ArrayDeque<>();
    directories.add(new Directory(DocumentsContract.getTreeDocumentId(tree), 0));
    Set<String> visited = new HashSet<>();
    ArrayList<Uri> files = new ArrayList<>();
    int count = 0;
    while (!directories.isEmpty()) {
      if (cancelled.getAsBoolean()) throw new IOException("Cancelled");
      Directory directory = directories.removeFirst();
      if (!visited.add(directory.id)) continue;
      if (visited.size() > 1024 || directory.depth > 16)
        throw new IOException("Folder tree too large");
      Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, directory.id);
      try (Cursor rows =
          resolver.query(
              children,
              new String[] {
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE
              },
              null,
              null,
              null)) {
        if (rows == null) throw new IOException("Cannot read folder");
        while (rows.moveToNext()) {
          if (++count > 10000 || cancelled.getAsBoolean()) throw new IOException("Scan stopped");
          String id = rows.getString(0), name = rows.getString(1), mime = rows.getString(2);
          if (id == null || name == null) continue;
          if (DocumentsContract.Document.MIME_TYPE_DIR.equals(mime))
            directories.addLast(new Directory(id, directory.depth + 1));
          else if (name.toLowerCase(Locale.ROOT).matches(".*\\.(mid|midi|kar|mp3|wav|sf2)$"))
            files.add(DocumentsContract.buildDocumentUriUsingTree(tree, id));
        }
      }
    }
    return Collections.unmodifiableList(files);
  }
}
