# SlackMessages
Create messages for Slack Webhooks

### Note
This lacks extensive support for _all_ message attributes. This is primarilly so support simple to intermediate messages e.i messages, attachments, fields and actions.

## Use case

The ps1 file contains a collection of cmdlets that help create messages, as either objects or JSON, that can be used as a payload for a request to a Slack webhook. Currently I use this in conjuction with my https://github.com/NegativeZero000/KijijiListings module. 

It's usage can be considered tedious for some of the simplere messages but it helps when used in conjunction with other PowerShell objects and processes. 

## Sample Usage

### Simple Text message

    $payload = New-SlackMessage -Text "This is a multiline`n....message" -AsJson
    Invoke-RestMethod -Uri $hookURL -Method Post -Body $payload
    
   ![Simple Message Test](https://user-images.githubusercontent.com/14927596/35451828-83f28b66-0292-11e8-9f9a-4740571a13f5.png)


### Message containing an attachment with fields
    
    $payload = @{
        Text        = "This is a multiline`n....message" 
        UserName    = "Testing" 
        IconEmoji   = ":bell:" 
        Attachments = (New-SlackAttachment -Colour "Good" -Pretext "here comes the before" -Fields (New-SlackAttachmentField -Title "Field1" -Value "Value1"))
    }

    Invoke-RestMethod -Uri $hookURL -Method Post -Body (New-SlackMessage @payload -AsJSON)

   ![Slack Attachment Sample](https://user-images.githubusercontent.com/14927596/35451664-041a447e-0292-11e8-8e92-07d3ed7adb85.png)

    
    
