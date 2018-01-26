<#
.SYNOPSIS
    Takes a Kijiji Listing objects and converts it to a Slack Messsage
.DESCRIPTION
    Take the properties of a Kijiji Listing object and converts it to a slack object that can be sent directly to a webhook.
.PARAMETER Listing
    Listing object created with the KijijiListings Module.
.PARAMETER FieldsToDisplay
    String array defining the list of listing properies to display as fields in the Slack Attachment. 
.PARAMETER Flatten
    Switch defines behaviour with multiple messages. If False all listing are converted to their own message. If Flatten is 
    true then listings will be created as individual attachments in one Slack message. 
.PARAMETER AsJSON
    Defines if the output is to be a PowerShell object or a formatted JSON String. 
.EXAMPLE
    $newListings | Convert-KijijiListingObjectToSlackMessage
.INPUTS
   System.Management.Automation.PSCustomObject. Convert-KijijiListingObjectToSlackMessage accepts Kijiji.Listing objects via the pipeline
.OUTPUTS
   System.Management.Automation.PSCustomObject. Convert-KijijiListingObjectToSlackMessage returns custom Slack.Message objects
   System.String. Convert-KijijiListingObjectToSlackMessage returns Slack ready JSON Strings.
#>
function Convert-KijijiListingObjectToSlackMessage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory,
            Position=0,
            ValueFromPipeline)]
        [PSTypeName("Kijiji.Listing")]
        $Listing,

        [Parameter(Mandatory=$false)]
        [string[]]$FieldsToDisplay = ("Price", "Posted", "Distance","Location"),

        [Parameter(Mandatory=$false)]
        [switch]$Flatten,

        [Parameter(Mandatory=$false)]
        [switch]$AsJSON
    )

    begin{
        # Main message information
        $payload = @{
            # Will change text based on number of attachments. 
            text = ""
            username = "Slippy"
            iconemoji = ":slippy:"
            channel = "#kijijialerts" 
        }

        # Special condsiderations if the attachments are meant to be together. 
        if($Flatten){$attachments = New-Object System.Collections.ArrayList}
    }
    process{
        # Map Listing properties to Slack Attachment properties.
        $slackFields = foreach($fieldName in $FieldsToDisplay){
            New-SlackAttachmentField -Title $fieldName -Value $listing.$fieldName -Short
        }

        $attachment = @{
            Pretext  = "The following {0} identified" -f $(if($Flatten){"listing was"}else{"listings were"})
            AuthorName  = "Kijiji Search" 
            AuthorLink = "https:\\www.kijiji.ca"
            Text = $Listing.ShortDescription
            Colour  = "#00A4A4"
            Title = $Listing.Title
            ImageURL = $Listing.ImageURL
            Fields = $slackFields
        }

        # Send this down the pipe if its ready or collect for the end
        if($Flatten){
            [void]$attachments.Add((New-SlackAttachment @attachment))
        } else {
            # Decide if we are sending a completed object or JSON String
            $payload.text = "New Kijiji listing available!"
            $payload.attachments = @([pscustomobject]$attachment)

            New-SlackMessage @payload -AsJSON:$AsJSON
        }
    }
    end{
        # If to be flattened return the completed message
        if($Flatten){
            $payload.text = "New Kijiji listings available!"
            $payload.attachments = @($attachments)

            New-SlackMessage @payload -AsJSON:$AsJSON
        } 
    }
}

<#
.SYNOPSIS
    Creates an action object to be later merged into a Slack Attachment.
.DESCRIPTION
    Creates a simple action button code. Currently only supports buttons. 
.PARAMETER Type
    Provide button to tell Slack you want to render a button.
.PARAMETER Text
    A UTF-8 string label for this button. Be brief but descriptive and actionable.
.PARAMETER URL
    The fully qualified http or https URL to deliver users to. Invalid URLs will result in a message posted with the button omitted.
.PARAMETER Style
    Setting to primary turns the button green and indicates the best forward action to take. Providing danger turns the button 
    red and indicates it some kind of destructive action. Use sparingly. Be default, buttons will use the UI's default text color.
.EXAMPLE
    New-SlackAttachmentAction-Footer -Text "Das Boot" -URL "https://example.com"
.INPUTS
   None. You cannot pipe objects to New-SlackAttachmentAction
.OUTPUTS
   System.Management.Automation.PSCustomObject. New-SlackAttachmentAction returns custom Slack.Attachment.Action object
#>
function New-SlackAttachmentAction{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Button")]
        [string]$Type="Button",
        
        [Parameter(Mandatory,
            Position=0)]
        [string]$Text,

        [Parameter(Mandatory,
            Position=1)]
        [uri]$URL,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Primary","Danger","Default")]
        [string]$Style = "Default"
    )

    return [pscustomobject]@{
        PSTypeName = "Slack.Attachment.Action"
        Type  = $Type
        Text  = $Text
        URL   = $FooterIcon.AbsoluteUri
        Style = $Style
    }
}

<#
.SYNOPSIS
    Your message attachments may also contain a subtle footer, which is especially useful when citing content in conjunction with author parameters.
.DESCRIPTION
    PowerShell wrapper to make a footer to be included in an message.
.PARAMETER Footer
    Add some brief text to help contextualize and identify an attachment. Limited to 300 characters, and may be truncated further
    when displayed to users in environments with limited screen real estate.
.PARAMETER FooterIcon
    To render a small icon beside your footer text, provide a publicly accessible URL string in the footer_icon field. You must 
    also provide a footer for the field to be recognized.
.PARAMETER TimeStamp
    By providing the ts field with an integer value in "epoch time", the attachment will display an additional timestamp value 
    as part of the attachment's footer. This is different then the posts timestamp
.EXAMPLE
    New-SlackAttachmentFooter -Footer "Das Boot" -FooterIcon "https://cdn3.iconfinder.com/data/icons/diagram_v2/PNG/96x96/diagram_v2-12.png"
.INPUTS
   None. You cannot pipe objects to New-SlackAttachmentFooter
.OUTPUTS
   System.Management.Automation.PSCustomObject. New-SlackAttachmentFooter returns custom Slack.Attachment.Footer object
#>
function New-SlackAttachmentFooter{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory,
            Position=0)]
        [ValidateLength(0,300)]
        [string]$Footer,
        
        [Parameter(Mandatory=$false,
            Position=1)]
        [uri]$FooterIcon,

        [Parameter(Mandatory=$false,
            Position=2)]
        [datetime]$TimeStamp
    )

    return [pscustomobject]@{
        PSTypeName = "Slack.Attachment.Footer"
        footer = $Footer
        footer_icon = $FooterIcon.AbsoluteUri
        ts = [long](Get-Date $TimeStamp -UFormat "%s")
    }

}

<#
.SYNOPSIS
    Fields are defined as an array, and hashes contained within it will be displayed in a table inside the Slack message attachment.
.DESCRIPTION
    PowerShell wrapper to make a field to be included in an attachment.
.PARAMETER Title
    Shown as a bold heading above the value text. It cannot contain markup and will be escaped for you.
.PARAMETER Value
    The text value of the field. It may contain standard message markup and must be escaped as normal. May be multi-line.
.PARAMETER Short
    An optional flag indicating whether the value is short enough to be displayed side-by-side with other values.
.EXAMPLE
    New-SlackAttachmentField -Title "Testing" -Value "Hello World"
.INPUTS
   None. You cannot pipe objects to New-SlackAttachment
.OUTPUTS
   System.Management.Automation.PSCustomObject. New-SlackAttachmentField returns custom Slack.Attachment.Field object
#>
function New-SlackAttachmentField{
    [cmdletbinding()]
    param(
        $Title,

        [Alias("Text","String")]
        $Value,

        [switch]$Short = $false
    )

    return [pscustomobject]@{
        PSTypeName = "Slack.Attachment.Field"
        title      = $Title
        value      = $Value
        short      = $Short.IsPresent
    }
}

<#
.SYNOPSIS
    Create a single attachment for a slack webhook request
.DESCRIPTION
    Complete PowerShell wrapper to make an attachment for a Slack attachment. Used in JSON post requests. 
.PARAMETER Colour
    Like traffic signals, color-coding messages can quickly communicate intent and help separate them from 
    the flow of other messages in the timeline. An optional value that can either be one of good, warning, 
    danger, or any hex color code (eg. #439FE0). This value is used to color the border along the left side 
    of the message attachment.
.PARAMETER Pretext
    This is optional text that appears above the message attachment block.
.PARAMETER AuthorName
    Small text used to display the author's name.
.PARAMETER AuthorLink
    A valid URL that will hyperlink the AuthorName text mentioned above. Will only work if author_name 
    is present.
.PARAMETER AuthorIcon
    A valid URL that displays a small 16x16px image to the left of the author_name text. Will only work 
    if AuthorName is present.
.PARAMETER Title
    The title is displayed as larger, bold text near the top of a message attachment. 
.PARAMETER TitleLink    
    By passing a valid URL in the title_link parameter (optional), the title text will be hyperlinked.
.PARAMETER Text
    This is the main text in a message attachment, and can contain standard message markup. The content 
    will automatically collapse if it contains 700+ characters or 5+ linebreaks, and will display a 
    "Show more..." link to expand the content. Links posted in the text field will not unfurl.
.PARAMETER Fields
    Fields are defined as an array, and hashes contained within it will be displayed in a table inside 
    the message attachment.
.PARAMETER ImageUrl
    A valid URL to an image file that will be displayed inside a message attachment. We currently support 
    the following formats: GIF, JPEG, PNG, and BMP. Large images will be resized to a maximum width of 400px 
    or a maximum height of 500px, while still maintaining the original aspect ratio.
.PARAMETER ThumbURL
    A valid URL to an image file that will be displayed as a thumbnail on the right side of a message 
    attachment. We currently support the following formats: GIF, JPEG, PNG, and BMP.
.PARAMETER Footer
    Your message attachments may also contain a subtle footer, which is especially useful when citing 
    content in conjunction with author parameters. This will be a special Footer object.
.INPUTS
   None. You cannot pipe objects to New-SlackAttachment
.OUTPUTS
   System.Management.Automation.PSCustomObject. New-SlackAttachment returns custom Slack.Attachment objects
#>
function New-SlackAttachment{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$False)]
        [ValidateScript({"good", "warning", "danger" -contains $_ -or $_ -match '^#(?:[0-9a-fA-F]{3}){1,2}$'})]
        [Alias("Color")]
        [string]$Colour,

        [Parameter(Mandatory=$False,
            Position=1)]
        [string]$Pretext,

        [Parameter(Mandatory=$False)]
        [string]$AuthorName,

        [Parameter(Mandatory=$False)]
        [uri]$AuthorLink,

        [Parameter(Mandatory=$False)]
        [uri]$AuthorIcon,

        [Parameter(Mandatory=$False)]
        [string]$Title,

        [Parameter(Mandatory=$False)]
        [uri]$TitleLink,

        [Parameter(Mandatory=$False,Position=0)]
        [string]$Text,

        [Parameter(Mandatory=$False)]
        [PSTypeName("Slack.Attachment.Field")]
        [object[]]$Fields,

        [Parameter(Mandatory=$False)]
        [uri]$ImageURL,

        [Parameter(Mandatory=$False)]
        [uri]$ThumbURL,

        [Parameter(Mandatory=$False)]
        [PSTypeName("Slack.Attachment.Footer")]
        $Footer
    )
    
    return [pscustomobject]@{
		PSTypeName  = "Slack.Attachment"
		color       = $Colour
		pretext     = $Pretext
		author_name = $AuthorName
		author_link = $AuthorLink
		author_icon = $AuthorIcon
		title       = $Title
		title_link  = $TitleLink
		text        = $Text
		fields      = $Fields
		image_url   = $ImageURL
		thumb_url   = $ThumbURL
		footer      = $Footer.footer
		footer_icon = $Footer.footer_icon
		ts          = $footer.ts
    }
}


<#
.SYNOPSIS
    Create a message to be sent to a Slack webhook. 
.DESCRIPTION
    This will help build an object with which can then be sent to a Slack webhook to create a Slack message. 
    Supports fields and attachements. 
.PARAMETER Text
    Text of the message to send. See below for an explanation of formatting. This field is usually required, 
    unless you're providing only attachments instead.
.PARAMETER UserName
    Set your bot's user name. Must be used in conjunction with as_user set to false, otherwise ignored. See authorship below.
.PARAMETER IconEmoji
    Emoji to use as the icon for this message.
.PARAMETER Channel
    Channel, private group, or IM channel to send message to. Can be an encoded ID, or a name. See below for more details.
.PARAMETER AsJSON
    Defines if the output is to be a PowerShell object or a formatted JSON String. 
.PARAMETER Attachments
    Array of structured Slack attachments.
.EXAMPLE
    New-SlackMessage -Text "Simple Message"
.INPUTS
   None. You cannot pipe objects to New-SlackMessage
.OUTPUTS
   System.Management.Automation.PSCustomObject. New-SlackAttachment returns custom Slack.Message objects
   System.String. New-SlackAttachment returns Slack ready JSON Strings.
#>
function New-SlackMessage{
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory=$false)]
        [string]$UserName,
        
        [Parameter(Mandatory=$false)]
        $IconEmoji,

        [Parameter(Mandatory=$false)]
        $Channel,

        [Parameter(Mandatory=$false)]
        $Attachments,

        [switch]$AsJSON=$true
    )

    $slackMessageProperties = @{text = $Text}

    # Conditionally add other options based on presence. 
    if($UserName){$slackMessageProperties.username = $UserName}
    if($IconEmoji){$slackMessageProperties.icon_emoji = $IconEmoji}
    if($Channel){$slackMessageProperties.channel = $Channel}
    if($Attachments){$slackMessageProperties.attachments = @($Attachments)}

    $slackMessageObject = [pscustomobject]$slackMessageProperties

    if($AsJSON.IsPresent){
        return $slackMessageObject | ConvertTo-Json -Depth 10
    } else {
        return $slackMessageObject
    }
}
