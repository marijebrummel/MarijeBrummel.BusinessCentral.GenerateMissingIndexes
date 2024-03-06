Index Packages | Business Central

Marije Brummel - de KrosseMarije Brummel - de Krosse
Marije Brummel - de Krosse
Microsoft Azure Specialist - Dynamics Business Central Architect - SQL Server DBA - Power Platform - GitHub CI/CD - Author & Teacher
Gepubliceerd op 6 mrt. 2024
+ Volgen
Index Tuning is an Art... not an exact science...
If you have worked long enough in our ecosystem you've probably heard someone say this.

Working with indexes (or keys as they were called in the old days) is something of all times and like most things, it does not exactly get easier over time.

In the old days...
I'm not going to be caught saying that performance tuning of an old Navision system was easy... it was not... Also back in those days there were people specialized in this area. However... it was simply not possible to sort a report without creating an index (key) or show a flowfield without a SumIndexField.

There was hardly any external access to the database, everything was done through the frontend, and background transactions was something that only existed in our dreams.

Fast Forward to 2024 please
Let's not dwell in the past... today we have much more fun. Business Central is very flexible, allowing users to sort on any column, even flowfields. We can do that without any warning of performance issues.

If a customer complains? Then we just use "StartSession" right? So much easier than the Job Queue.

And for a long time... we did not care... Business Central hosted by Microsoft is fast... very fast.

But... then the database size gets to be over 100GB... (COMPRESSED!!)
If your Business Central cloud database hits over 100GB you'll get close to the equivalent of 0,5TB in the old OnPrem days. When this happens background transactions can start causing problems.

Database Missing Indexes
When Business Central in the cloud is hosted by Microsoft you don't have access to the back-end anymore. That includes all the information by Azure SQL too.

Fortunately our friends in Lyngby know that and they give us what we need in alternative ways.


One of these is Database Missing Indexes or "sys.dm_db_missing_index_details"

When you export this information to an Excel Spreadsheet it actually shows some fairly useful information.


If we focus on line # 5 it tells us that we need to create an index for Posting Date and Document No. for the G/L Entry table.

In AL with Visual Studio we would have to create something that looks like this to satisfy this.


All we need is a table extension that only contains keys (indexes).

Marije, Is there a tool for this?
I am a lazy girl... so I've created a tool.

No... scratch that... I am not lazy... I am a mother of five! I have better things to do with my time than translating an Excel Sheet to AL code...

So I've created a tool... and the tool for this project (a 122GB database) has created 19 Table Extensions with indexes. And since it also creates indexes for AppSource Apps like ApTean Workflow & Continia Document Capture it will also generate an App.json with the correct dependencies.


You can find the tool on my GitHub here

https://github.com/marijebrummel/MarijeBrummel.BusinessCentral.GenerateMissingIndexes

Please don't judge me by my code... I know I should probably split the "one codeunit" into a few more... #CleanCode

But now what?
So now we have an Extension in AL that will magically solve all performance issues if I deploy it?

I wish it were true... no... please do not just publish this extension! Please don't!

There are several reasons for that and let me start with the obvious.

Included Columns
The Excel Sheet contains three columns. Index Equality Columns & Index Inequality Columns are fairly straight forward and you should be able to trust SQL Server on those.

Equality means that someone searches or filters on an EXACT value where Inequality means they use the oposite.

If you are familiar with creating SQL Server indexes you'll know to put the exact values first and the latter at the end. Simple.

However... if you look at Index Include Columns you'll see that in many cases SQL Server suggests far to many columns.

This is a result of legacy code that does not use SetLoadFields. If you don't use this cool feature SQL Server will read all fields of a table instead of the specific ones you need.

My tool will convert this column in the Excel sheet nicely to AL but you'll need to clean it up.

Why does Business Central need an index?
Instead of creating this Index Extension and loading it with a blindfold on you can also use the content of the package as clues... to investigate why certain indexes are needed.

What I typically try to do is cross reference the indexes with telemetry from Application Insights.

There are several ways to do that and most of then require pretty advanced KQL skills and I won't go into that in this post.

Telemetry will give you a lead on where to search in the Business Central application. Most of the time you'll get at least an object type and id and if you are lucky you'll get a lead on some AL code too.

This is where I use Statical Prism to research code. Prism for me replaces C/Side and has a much better user interface than Visual Studio Code.

Indexes on G/L Entries
When I investigate the index suggestions on the General Ledger Entries and cross reference them with Telemetry it leads me to Page 19...


This page is connected to page 20 based on Document No. and Posting Date, but the page itself sorts on G/L Account No. SQL Server does not like that... a mismatch between sorting and filtering.

An alternative solution to creating the index could be to make this Page Part invisible.

SystemCreatedAt
Another Index Suggestion was to add an index on quite a lot of tables with the field SystemCreatedAt.


This originates from the System App. In Business Central you can see how your database grows in the last 30 days. The system app calculates the growth using a RecordRef variable and filters on SystemCreatedAt.

These index suggestions appeared obviously because we are investigating performance issues and we are poking around in the database.

After a while these index suggestions disappeared by itself because nobody looked at this data anymore.

They are all clues! And you need to spend time investigating!
Index Tuning is not only an art... the best consultants will help you avoid doing it all together and will always ask "why??".

Why does this index show up in the list and what can we do to avoid having to create the index.

Sometimes creating the index is the best way to go... but very often it's much better to ask further.
