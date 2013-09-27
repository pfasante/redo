{-# LANGUAGE StandaloneDeriving #-}

import Control.Monad (filterM, liftM)
import Data.Map.Lazy (adjust, insert, fromList, toList)
import Data.Maybe (listToMaybe)
import Debug.Trace (traceShow)
import System.Directory (doesFileExist, renameFile, removeFile)
import System.Environment (getArgs, getEnvironment)
import System.Exit (ExitCode(..))
import System.FilePath (hasExtension, replaceBaseName, takeBaseName)
import System.IO (hPutStrLn, stderr)
import System.Process (createProcess, shell, waitForProcess, CreateProcess(..), StdStream(..), CmdSpec(..))

traceShow' arg = traceShow arg arg

deriving instance Show CreateProcess
deriving instance Show StdStream
deriving instance Show CmdSpec

main :: IO ()
main = mapM_ redo =<< getArgs

redo :: String -> IO ()
redo target = maybe printMissing redo'=<< redoPath target
 where redo' :: FilePath -> IO ()
       redo' path = do
         oldEnv <- getEnvironment
         let newEnv = toList $ adjust (++ ":.") "PATH"  $ insert "REDO_TARGET" target $ fromList oldEnv
         (_,_,_,ph) <- createProcess $ traceShow' $ (shell $ cmd path) {env = Just newEnv}
         exit <- waitForProcess ph
         case exit of
           ExitSuccess -> do renameFile tmp target
           ExitFailure code -> do hPutStrLn stderr $ "Redo script exited with non-zero exit code: " ++ show code
                                  removeFile tmp
       printMissing = error $ "No .do file found for target '" ++ target ++ "'"
       tmp = target ++ "---redoing"
       cmd path = traceShow' $ unwords ["sh", path, "0", takeBaseName target, tmp, ">", tmp]

redoPath :: FilePath -> IO (Maybe FilePath)
redoPath target = listToMaybe `liftM` filterM doesFileExist candidates 
 where candidates = [target ++ ".do"] ++ if hasExtension target
                                         then [replaceBaseName target "default" ++ ".do"]
                                         else []
