{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE TypeOperators #-}

module Api.Types where

import           Data.Aeson (FromJSON, ToJSON)
import qualified Data.Map.Strict as Map
import           Data.Text (Text)
import           Elm (ElmType)
import           GHC.Generics (Generic)
import           Prelude hiding (id)
import           Servant ((:<|>), (:>), Capture, ReqBody, Post, Get, JSON)

data Story = Story
    { id :: Maybe StoryId
    , img :: Text
    , title :: Text
    , tags :: [Text]
    , level :: Int
    , words :: [DictEntry]
    , date :: Text
    , content :: Text
    } deriving (Show, Generic, ElmType, ToJSON, FromJSON)

data DictEntry = DictEntry
    { word :: Text
    , index :: Int
    } deriving (Show, Generic, ElmType, ToJSON, FromJSON)

type StoryId = Text

type WordDefinition = (Text, [(Text, Int)])

type WordDictionary = Map.Map Text [WordDefinition]

data School = School
    { id :: SchoolId
    , name :: Text
    } deriving (Show, Generic, ElmType, ToJSON, FromJSON)

type SchoolId = Text

data Class = Class
    { id :: ClassId
    , name :: Text
    , schoolId :: SchoolId
    , students :: [StudentId]
    } deriving (Show, Generic, ElmType, ToJSON, FromJSON)

type ClassId = Text

data Teacher = Teacher
    { id :: Text
    , name :: Text
    , schoolId :: SchoolId
    } deriving (Show, Generic, ElmType, ToJSON, FromJSON)

data Student = Student
    { id :: StudentId
    , name :: Text
    , schoolId :: SchoolId
    } deriving (Show, Generic, ElmType, ToJSON, FromJSON)

type StudentId = Text

data LoginRequest = LoginRequest
    { username :: Text
    , password :: Text
    } deriving (Show, Generic, ElmType, ToJSON, FromJSON)

data Login = Login
    { sub :: SubjectId
    , username :: Text
    , name :: Text
    , role :: UserType
    , token :: AccessToken
    } deriving (Show, Generic, ElmType, ToJSON, FromJSON)

type SubjectId = Text

newtype AccessToken = AccessToken {accessToken :: Text}
    deriving (Show, Generic, ElmType, ToJSON, FromJSON)

-- Change this to an ADT when elm-export support lands
newtype UserType = UserType {userType :: Text }
    deriving (Show, Generic, ElmType, ToJSON, FromJSON)

student, teacher, editor, admin :: UserType
student = UserType "Student"
teacher = UserType "Teacher"
editor = UserType "Editor"
admin = UserType "Admin"

data DB = DB
    { stories :: Map.Map StoryId Story
    , dictionary :: WordDictionary
    }

type LoginApi =
    "authenticate" :> ReqBody '[JSON] LoginRequest :> Post '[JSON] Login

type StoriesApi =
    "stories" :>
        (    Get '[JSON] [Story]
        :<|> Capture "storyId" Text :> Get '[JSON] Story
        :<|> ReqBody '[JSON] Story :> Post '[JSON] Story
        )

type DictApi =
    "dictionary" :>
        (    Get '[JSON] WordDictionary
        :<|> Capture "word" Text :> Get '[JSON] [WordDefinition]
        )

type SchoolsApi =
    "schools" :>
        (    Get '[JSON] [School]
        :<|> Capture "schoolId" SchoolId :>
             ( "classes" :>
                 (    Get '[JSON] [Class]
                 :<|> Capture "classId" ClassId :> Get '[JSON] Class
                 )
             )
        )

type Api = StoriesApi :<|> DictApi :<|> SchoolsApi :<|> LoginApi