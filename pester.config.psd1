@{
    Version = '5.0'
    TestSuite = @{
        Name = 'Azoo.Tests'
        Path = 'tests'
    }
    Output = @{
        Verbose = $true
        Format = 'Text'
    }
    CodeCoverage = @{
        Enable = $true
        Path = 'src/Azoo'
    }
}