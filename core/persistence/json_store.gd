class_name IEGJsonStore
extends RefCounted
## Écriture locale partagée : le fichier définitif reste intact si l'écriture échoue.

static func write_document(storage_path: String, document: String, errors: PackedStringArray, max_bytes: int = 524288) -> Error:
    if document.to_utf8_buffer().size() > max_bytes:
        errors.append("La sauvegarde dépasserait la taille maximale autorisée (%d octets)." % max_bytes)
        return ERR_INVALID_DATA
    var temporary: String = storage_path + ".tmp"
    var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        var open_error: Error = FileAccess.get_open_error()
        errors.append("Impossible de créer le fichier local : " + error_string(open_error))
        return open_error
    file.store_string(document)
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    if write_error != OK:
        errors.append("Impossible d'écrire la sauvegarde : " + error_string(write_error))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return write_error
    var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(storage_path))
    if rename_error != OK:
        errors.append("Impossible de remplacer la sauvegarde : " + error_string(rename_error))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return rename_error
    return OK
