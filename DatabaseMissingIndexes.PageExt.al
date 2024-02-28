pageextension 99900 "PTE Database Missing Indexes" extends "Database Missing Indexes"
{

    actions
    {
        addfirst(Processing)
        {
            action(GenerateIndexExtension)
            {
                ApplicationArea = All;
                Caption = 'Generate Index Extension';
                trigger OnAction()
                var
                    GenIndexPackage: Codeunit "PTE Generate Index Package";
                begin
                    GenIndexPackage.Run();
                end;
            }
        }
    }
}