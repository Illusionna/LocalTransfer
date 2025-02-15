package main


type TIME_RANGE int64


var CONTENTEDITABLE string = ""


var USER_LOCK map[string]bool = map[string]bool{"localhost+curl": false}


type CONTENTEDITABLE_REQUEST struct {
	Content	string	`json:"Content"`
}


type FILE_INFO struct {
	FileName		string	`json:"FileName"`
	FileSize		string	`json:"FileSize"`
	FileIcon		string	`json:"FileIcon"`
	ModifiedTime	string	`json:"ModifiedTime"`
}


type FILE_PROPERTY struct {
	FileCount		int64	`json:"FileCount"`
	SumSize			string	`json:"SumSize"`
	ModifiedTime	string	`json:"ModifiedTime"`
	AgoTime			string	`json:"AgoTime"`
}


type FILE_REQUEST struct {
	Path		string	`json:"Path"`
	CurrentDir	string	`json:"CurrentDir"`
}


type FILE_RENAME struct {
	CurrentDir	string	`json:"CurrentDir"`
	OldName		string 	`json:"OldName"`
	NewName		string	`json:"NewName"`
	Prefix		string 	`json:"Prefix"`
	Suffix		string 	`json:"Suffix"`
}


type STANDARD_SEARCH struct {
	Path	string	`json:"Path"`
	Target	string 	`json:"Target"`
	StandardSearchStatus	bool	`json:"StandardSearchStatus"`
	KeywordSearchStatus		bool	`json:"KeywordSearchStatus"`
}