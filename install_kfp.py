!pip install --user virtualenv
!/home/jovyan/.local/bin/virtualenv kfpenv
!pip install --user ipykernel
!python -m ipykernel install --user --name=kfpenv
!kfpenv/bin/pip install kfp
# Now reload pace- then go to Kernel, change kerenetl, kfpenv

import kfp

@kfp.dsl.pipeline(
    name="COVID Blog Demo",
    description="Do various statistical analysis at a county level and publish blog post about it."
)
def covid_blog_pipeline():
    step1 = kfp.dsl.ContainerOp(
        name="download-dicom",
        image="rawkintrevo/download-dicom:0.0.0.4",
        command=["/run.sh"],
        pvolumes={"/data": vop.volume}
    )
    step2 = kfp.dsl.ContainerOp(
        name="convert-dicoms-to-vectors",
        image="rawkintrevo/covid-prep-dicom:0.9.5",
        arguments=[
            '--bucket_name', "covid-dicoms",
        ],
        command=["python", "/program.py"],
        pvolumes={"/mnt/data": step1.pvolume}
    ).apply(kfp.gcp.use_gcp_secret(secret_name='user-gcp-sa'))


kfp.compiler.Compiler().compile(covid_dicom_pipeline,"dicom-pipeline-2.zip")
client = kfp.Client()

my_experiment = client.create_experiment(name='my-experiments')
my_run = client.run_pipeline(my_experiment.id, 'my-run1', 'dicom-pipeline-2.zip')
