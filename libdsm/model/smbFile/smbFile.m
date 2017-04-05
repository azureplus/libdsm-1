//
//  smbFile.m
//  libdsm
//
//  Created by trekvn on 4/4/17.
//  Copyright © 2017 trekvn. All rights reserved.
//
#import "smbFile.h"
#import "smbFile_Protected.h"
#import "smbShare_Protected.h"
#import "smbError.h"
#import "smb_file.h"

@interface smbFile ()
@property (nonatomic) dispatch_queue_t      serialQueue;
@property (nonatomic) smb_fd                fileID;
@end

@implementation smbFile

+ (instancetype)rootOfShare:(smbShare *)share {
    smbFile *root = [[self alloc] initWithPath:@"/" share:share];
    
    root.smbStat = [smbStat statForRoot];
    
    return root;
}

+ (nullable instancetype)fileWithPath:(nonnull NSString *)path share:(nonnull smbShare *)share {
    return [[self alloc] initWithPath:path share:share];
}

+ (nullable instancetype)fileWithPath:(nonnull NSString *)path relativeToFile:(nonnull smbFile *)file {
    return [[self alloc] initWithPath:path relativeToFile:file];
}

- (instancetype)initWithPath:(NSString *)path share:(smbShare *)share {
    self = [super init];
    if (self) {
        NSString *queueName = [NSString stringWithFormat:@"smb_file_queue_%@", path];
        
        _path = path;
        _share = share;
        _serialQueue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
        
        if ([_path isEqualToString:@"/"]) {
            self.smbStat = [smbStat statForRoot];
        } else {
            if (![_path hasPrefix:@"/"]) {
                _path = [@"/" stringByAppendingString:_path];
            }
            
            if ([_path hasSuffix:@"/"]) {
                _path = [_path substringToIndex:_path.length - 1];
            }
        }
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path relativeToFile:(smbFile *)file {
    NSString *p = file.path;
    
    if (file.isDirectory) {
        p = [p stringByAppendingString:@"/"];
    }
    
    NSURL *url = [NSURL fileURLWithPath:p];
    NSString *absolutePath = [NSURL fileURLWithPath:path relativeToURL:url].path;
    
    return [self initWithPath:absolutePath share:file.share];
}

- (NSString *)description {
    if (_smbStat) {
        return [NSString stringWithFormat:@"%@ (%@)", _path, _smbStat.description];
    } else {
        return _path;
    }
}

#pragma mark - Public methods

- (smbFile *)parent {
    smbFile *parent = nil;
    NSString *path;
    
    if ([self.path isEqualToString:@"/"]) {
        path = nil;
    } else {
        path = [self.path stringByDeletingLastPathComponent];
    }
    
    if (path.length) {
        parent = [[smbFile alloc] initWithPath:path share:self.share];
    }
    
    return parent;
}

- (void)open:(smbFileMode)mode completion:(nullable void (^)(NSError *_Nullable))completion {
    
    dispatch_async(_serialQueue, ^{
        
        [self.share openFile:self.path mode:mode completion:^(smbFile *file, smb_fd fileID, NSError *error) {
            if (error == nil) {
                _fileID = fileID;
                _smbStat = file.smbStat;
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(error);
                });
            }
        }];
    });
    
}

- (void)close:(nullable void (^)(NSError *_Nullable))completion {
    
    dispatch_async(_serialQueue, ^{
        
        if (_fileID == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([smbError notOpenError]);
            });
        } else {
            [self.share closeFile:_fileID path:self.path completion:^(smbFile *file, NSError * _Nullable error) {
                if (error == nil) {
                    _fileID = 0;
                    _smbStat = file.smbStat;
                }
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(error);
                    });
                }
            }];
            
        }
    });
}

- (BOOL)isOpen {
    return _fileID > 0;
}

- (void)seek:(unsigned long long)offset absolute:(BOOL)absolute completion:(nullable void (^)(unsigned long long, NSError *_Nullable))completion {
    
    dispatch_async(_serialQueue, ^{
        
        NSError *error = nil;
        unsigned long long position = 0;
        
        if (self.share.server.smbSession) {
            if ([self isOpen]) {
                
                off_t pos = smb_fseek(self.share.server.smbSession, _fileID, offset, absolute ? SMB_SEEK_SET : SMB_SEEK_CUR);
                
                position = MAX(0L, pos);
                
                if (pos < 0L) {
                    error = [smbError seekError];
                }
                
            } else {
                error = [smbError notOpenError];
            }
        } else {
            error = [smbError notConnectedError];
        }
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(position, error);
            });
        }
        
    });
}

- (void)read:(NSUInteger)bufferSize progress:(nullable BOOL (^)(unsigned long long, NSData *_Nullable, BOOL, NSError *_Nullable))progress {
    [self read:bufferSize maxBytes:0 progress:progress];
}

- (void)read:(NSUInteger)bufferSize maxBytes:(unsigned long long)maxBytes progress:(nullable BOOL (^)(unsigned long long, NSData *_Nullable, BOOL, NSError *_Nullable))progress {
    
    dispatch_async(_serialQueue, ^{
        
        NSError *error = nil;
        __block BOOL finished = NO;
        unsigned long long bytesReadTotal = 0;
        
        if (self.share.server.smbSession) {
            if ([self isOpen]) {
                
                char buf[bufferSize];
                
                if (progress) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        BOOL readMore = progress(bytesReadTotal, nil, NO, error);
                        
                        if (!readMore) {
                            finished = YES;
                        }
                    });
                }
                
                while (!finished) {
                    
                    NSUInteger bytesToRead = maxBytes == 0 ? bufferSize : MIN(bufferSize, (NSUInteger)(maxBytes - bytesReadTotal));
                    long bytesRead = smb_fread(self.share.server.smbSession, _fileID, buf, bytesToRead);
                    
                    if (bytesRead < 0) {
                        finished = YES;
                        error = [smbError readError];
                    } else if (bytesRead == 0) {
                        finished = YES;
                    } else {
                        bytesReadTotal += bytesRead;
                        
                        if (bytesReadTotal == maxBytes) {
                            finished = YES;
                        }
                        
                        if (progress) {
                            NSData *data = [NSData dataWithBytes:buf length:bytesRead];
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                BOOL readMore = progress(bytesReadTotal, data, NO, error);
                                
                                if (!readMore) {
                                    finished = YES;
                                }
                            });
                        }
                    }
                }
            } else {
                finished = YES;
                error = [smbError notOpenError];
            }
        } else {
            finished = YES;
            error = [smbError notConnectedError];
        }
        
        if (progress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                progress(bytesReadTotal, nil, YES, error);
            });
        }
    });
}

- (void)write:(nonnull NSData *_Nullable (^)(unsigned long long))dataHandler progress:(nullable void (^)(unsigned long long, long, BOOL, NSError *_Nullable))progress {
    
    dispatch_async(_serialQueue, ^{
        
        NSError *error = nil;
        unsigned long long offset = 0;
        BOOL finished = NO;
        
        if (self.share.server.smbSession) {
            if ([self isOpen]) {
                
                NSData *data;
                
                if (progress) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        progress(offset, 0, finished, error);
                    });
                }
                
                while (!finished) {
                    
                    data = dataHandler(offset);
                    
                    if (data.length == 0) {
                        finished = YES;
                    } else {
                        long bytesToWrite = data.length;
                        long bytesWritten = smb_fwrite(self.share.server.smbSession, _fileID, (void *)data.bytes, bytesToWrite);
                        
                        offset += MAX(0, bytesWritten);
                        
                        if (bytesWritten != bytesToWrite) {
                            finished = YES;
                            error = [smbError writeError];
                        } else {
                            if (progress) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    progress(offset, MAX(0, bytesWritten), finished, error);
                                });
                            }
                        }
                    }
                }
            } else {
                finished = YES;
                error = [smbError notOpenError];
            }
        } else {
            finished = YES;
            error = [smbError notConnectedError];
        }
        
        if (progress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                progress(offset, 0, finished, error);
            });
        }
    });
}

- (void)listFiles:(nullable void (^)(NSArray<smbFile *> *_Nullable, NSError *_Nullable))completion {
    [self listFilesUsingFilter:nil completion:completion];
}

- (void)listFilesUsingFilter:(nullable BOOL (^)(smbFile *_Nonnull file))filter completion:(nullable void (^)(NSArray<smbFile *> *_Nullable files, NSError *_Nullable error))completion {
    //if (_smbStat == nil || !self.exists) {
    [self updateStatus:^(NSError *error) {
        if (error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
        } else if (!self.hasStatus || !self.isDirectory) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [smbError notSuchFileOrDirectory]);
            });
        } else {
            [self.share listFiles:self.path filter:filter completion:completion];
        }
    }];
    //} else {
    //    [self.share listFiles:self.path filter:filter completion:completion];
    //}
}

- (void)updateStatus:(nullable void (^)(NSError *_Nullable))completion {
    [self.share getStatusOfFile:self.path completion:^(smbStat * _Nullable smbStat, NSError * _Nullable error) {
        if (error == nil) {
            _smbStat = smbStat;
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    }];
}

- (void)createDirectory:(nullable void (^)(NSError *_Nullable))completion {
    [self.share createDirectory:self.path completion:^(smbFile * _Nullable file, NSError * _Nullable error) {
        if (error == nil) {
            _smbStat = file.smbStat;
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    }];
}

- (void)createDirectories:(nullable void (^)(NSError *_Nullable))completion {
    [self.share createDirectories:self.path completion:^(smbFile * _Nullable file, NSError * _Nullable error) {
        if (error == nil) {
            _smbStat = file.smbStat;
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    }];
}

- (void)deleteFile:(nullable void (^)(NSError *_Nullable))completion {
    [self.share deleteFile:self.path completion:^(NSError * _Nullable error) {
        if (error == nil) {
            _smbStat = [smbStat statForNonExistingFile];
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    }];
}

- (void)moveTo:(nonnull NSString *)path completion:(nullable void (^)(NSError *_Nullable))completion {
    smbFile *f = [smbFile fileWithPath:path relativeToFile:self];
    
    [self.share moveFile:self.path to:f.path completion:^(smbFile *_Nullable newFile, NSError * _Nullable error) {
        if (error == nil) {
            _smbStat = newFile.smbStat;
            _path = newFile.path;
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    }];
}

#pragma mark - Overwritten getters and setters

- (NSString *)name {
    return _path.pathComponents.lastObject;
}

- (BOOL)exists {
    return self.smbStat.exists;
}

- (BOOL)isDirectory {
    return self.smbStat.isDirectory;
}

- (unsigned long long)size {
    return self.smbStat.size;
}

- (NSDate *)creationTime {
    return self.smbStat.creationTime;
}

- (NSDate *)modificationTime {
    return self.smbStat.modificationTime;
}

- (NSDate *)accessTime {
    return self.smbStat.accessTime;
}

- (NSDate *)writeTime {
    return self.smbStat.writeTime;
}

- (NSDate *)statusTime {
    return self.smbStat.statTime;
}

- (BOOL)hasStatus {
    return self.smbStat != nil;
}
@end
