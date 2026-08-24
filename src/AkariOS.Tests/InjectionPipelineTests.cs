using AkariOS.Core.Pipeline;
using Xunit;

namespace AkariOS.Tests;

public class InjectionPipelineTests
{
    private sealed class FakeStep(string name, Action<BuildContext>? onExecute = null) : IBuildStep
    {
        public string Name { get; } = name;
        public int Executions { get; private set; }

        public Task ExecuteAsync(InjectionOptions options, BuildContext context, IProgress<ProgressReport> progress, CancellationToken ct)
        {
            Executions++;
            onExecute?.Invoke(context);
            return Task.CompletedTask;
        }
    }

    private static InjectionOptions Options() => new()
    {
        SourceIsoPath = @"C:\iso\win11.iso",
        PayloadFiles = ["WinSux.ps1"],
    };

    [Fact]
    public async Task Runs_all_steps_in_order_and_reports_done()
    {
        var order = new List<string>();
        var steps = new[]
        {
            new FakeStep("mount", _ => order.Add("mount")),
            new FakeStep("inject", _ => order.Add("inject")),
        };
        var reports = new List<ProgressReport>();
        var progress = new Progress<ProgressReport>(reports.Add);

        var pipeline = new InjectionPipeline(steps);
        var result = await pipeline.RunAsync(Options(), progress);

        Assert.True(result.Success);
        Assert.Equal(["mount", "inject"], order);
        Assert.Contains(reports, r => r.Stage == BuildStage.Done);
    }

    [Fact]
    public async Task Returns_error_result_when_step_throws()
    {
        var steps = new[] { new FakeStep("boom", _ => throw new IOException("disk full")) };
        var pipeline = new InjectionPipeline(steps);

        var result = await pipeline.RunAsync(Options(), new Progress<ProgressReport>(_ => { }));

        Assert.False(result.Success);
        Assert.Equal("disk full", result.ErrorMessage);
    }
}
