# ISO Builder removal group, ported from Tiny11 Builder (ntdevlabs, used with its developers' permission: ADR 0010,
# docs/permissions/tiny11builder.md) at commit 38f7ab6b1f177098c026a19b73ec84bca9c4b874: src/Tiny11Builder.Core/CleanupCatalog.cs, the
# optional features of the Tiny11 mode ("xps", "workfolders", "legacy", "recall-feature").
@{
    Name        = 'Optional Windows features (Tiny11)'
    Description = 'XPS printing, Work Folders, the old Internet Explorer and Recall turned off and their files removed, where the image has them.'
    Kind        = 'Features'
    Risk        = 'Safe'
    Order       = 7
    Features    = @('Printing-XPSServices-Features', 'WorkFolders-Client', 'Internet-Explorer-Optional-amd64', 'Internet-Explorer-Optional-arm64', 'Recall')
}
